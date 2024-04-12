require 'luca_deal/version'

require 'mail'
require 'json'
require 'yaml'
require 'pathname'
require 'bigdecimal'
require 'luca_support/code'
require 'luca_support/mail'
require 'luca_deal/contract'
require 'luca_record'

module LucaDeal
  class Invoice < LucaRecord::Base
    @dirname = 'invoices'
    @required = ['issue_date', 'customer', 'items', 'subtotal']

    def initialize(date = nil)
      @date = issue_date(date)
    end

    def deliver_mail(attachment_type = nil, mode: nil)
      invoices = self.class.asof(@date.year, @date.month)
      raise "No invoice for #{@date.year}/#{@date.month}" if invoices.count.zero?

      invoices.each do |dat, path|
        next if has_status?(dat, 'mail_delivered')

        deliver_one(dat, path, mode: mode, attachment_type: attachment_type)
      end
    end

    def preview_mail(attachment_type = nil)
      invoices = self.class.asof(@date.year, @date.month)
      raise "No invoice for #{@date.year}/#{@date.month}" if invoices.count.zero?

      invoices.each do |dat, path|
        deliver_one(dat, path, mode: :preview, attachment_type: attachment_type)
      end
    end

    # Render HTML/PDF to files
    # TODO: change output dir
    #
    def print(id = nil, params = {})
      filetype = params[:output] || :html
      if id
        dat = self.class.find(id)
        @company = set_company
        invoice_vars(dat, params[:sample])
        File.open(attachment_name(dat, filetype), 'w') do |f|
          f.puts render_invoice(filetype)
        end
      else
        self.class.asof(@date.year, @date.month) do |dat, _|
          @company = set_company
          invoice_vars(dat, params[:sample])
          File.open(attachment_name(dat, filetype), 'w') do |f|
            f.puts render_invoice(filetype)
          end
        end
      end
    end

    def compose_mail(dat, mode: nil, attachment: :html)
      @company = set_company
      invoice_vars(dat)

      mail = Mail.new
      mail.to = dat.dig('customer', 'to') if mode.nil?
      mail.subject = LucaRecord::CONST.config.dig('invoice', 'mail_subject') || 'Your Invoice is available'
      if mode == :preview
        mail.cc = LucaRecord::CONST.config.dig('mail', 'preview') || LucaRecord::CONST.config.dig('mail', 'from')
        mail.subject = '[preview] ' + mail.subject
      end
      mail.text_part = Mail::Part.new(body: render_erb(search_template('invoice-mail.txt.erb')), charset: 'UTF-8')
      mail.attachments[attachment_name(dat, attachment)] = render_invoice(attachment)
      mail
    end

    def render_invoice(file_type = :html)
      case file_type
      when :html
        render_erb(search_template('invoice.html.erb'))
      when :pdf
        erb2pdf(search_template('invoice.html.erb'))
      else
        raise 'This filetype is not supported.'
      end
    end

    def self.report(date, scan_years = 10, detail: false, due: false)
      fy_end = Date.new(date.year, date.month, -1)
      customers = {}.tap do |h|
        Customer.all.each { |c| h[c['id']] = LucaSupport::Code.parse_current(c, fy_end) }
      end
      [].tap do |res|
        items = {}
        head = date.prev_year(scan_years)
        e = Enumerator.new do |yielder|
          while head <= date
            yielder << head
            head = head.next_month
          end
        end
        e.each do |d|
          asof(d.year, d.month).map do |invoice|
            if invoice['settled']
              next if !due
              settle_date = invoice['settled']['date'].class.name == "String" ? Date.parse(invoice['settled']['date']) : invoice['settled']['date']
              next if (settle_date && settle_date <= fy_end)
            end

            customer = invoice.dig('customer', 'id')
            items[customer] ||= { 'unsettled' => BigDecimal('0'), 'invoices' => [] }
            items[customer]['unsettled'] += (invoice.dig('subtotal', 0, 'items') + invoice.dig('subtotal', 0, 'tax')||0)
            items[customer]['invoices'] << invoice
          end
        end
        items.each do |k, item|
          row = {
            'id' => k,
            'customer' => customers.dig(k, 'name'),
            'unsettled' => LucaSupport::Code.readable(item['unsettled']),
          }
          if detail
            row['address'] = %Q(#{customers.dig(k, 'address')}#{customers.dig(k, 'address2')})
            row['invoices'] = item['invoices'].map{ |i| { 'id' => i['id'], 'issue' => i['issue_date'].to_s } }
          end
          res << row
        end
        res.sort! { |a, b| b['unsettled'] <=> a['unsettled'] }
      end
    end

    # === JSON Format:
    #   [
    #     {
    #       "journals" : [
    #         {
    #           "id": "2021A/U001",
    #           "header": "customer name",
    #           "diff": -20000
    #         }
    #       ]
    #     }
    #   ]
    #
    def self.settle(io, payment_terms = 1)
      customers = {}.tap do |h|
        Customer.all.each do |c|
          LucaSupport::Code.take_history(c, 'name').each do |name|
            h[name] = c
          end
        end
      end
      contracts = {}.tap do |h|
        Contract.all.each { |c| h[c['customer_id']] ||= []; h[c['customer_id']] << c }
      end
      JSON.parse(io).each do |d|
        next if d['journals'].nil?

        d['journals'].each do |j|
          next if j['diff'] >= 0

          if j['header'] == 'others'
            STDERR.puts "#{j['id']}: no customer header found. skip"
            next
          end

          ord = customers.map do |k, v|
            [v, LucaSupport::Code.match_score(j['header'], k, 2)]
          end
          customer = ord.max { |x, y| x[1] <=> y[1] }.dig(0, 'id')

          if customer
            contract = contracts[customer].length == 1 ? contracts.dig(customer, 0, 'id') : nil
            date = Date.parse(j['date'])
            invoices = term(date.prev_month(payment_terms).year, date.prev_month(payment_terms).month, date.year, date.month, contract)
            invoices.each do |invoice, _path|
              next if invoice['customer']['id'] != customer
              next if invoice['issue_date'] > date
              if Regexp.new("^LucaBook/#{j['id']}").match invoice.dig('settled', 'id')||''
                break
              end
              next if 0 >= [
                  invoice.dig('subtotal', 0, 'items'),
                  invoice.dig('subtotal', 0, 'tax'),
                  invoice.dig('settled', 'amount')
                ].compact.sum

              invoice['settled'] = {
                'id' => "LucaBook/#{j['id']}",
                'date' => j['date'],
                'amount' => j['diff']
              }
              save(invoice)
              break
            end
          else
            STDERR.puts "#{j['id']}: no customer found"
          end
        end
      end
    end

    # Output seriarized invoice data to stdout.
    # Returns previous N months on multiple count
    #
    # === Example YAML output
    #   ---
    #   - records:
    #     - customer: Example Co.
    #       subtotal: 100000
    #       tax: 10000
    #       due: 2020-10-31
    #       issue_date: '2020-09-30'
    #     count: 1
    #     total: 100000
    #     tax: 10000
    #
    def stats(count = 1, mode: nil)
      [].tap do |collection|
        scan_date = @date.next_month
        count.times do
          scan_date = scan_date.prev_month
          {}.tap do |stat|
            stat['records'] = self.class.asof(scan_date.year, scan_date.month).map do |invoice|
              amount = invoice['subtotal'].inject(0) { |sum, sub| sum + sub['items'] }
              tax = invoice['subtotal'].inject(0) { |sum, sub| sum + sub['tax'] }
              {
                'customer' => invoice.dig('customer', 'name'),
                'subtotal' => amount,
                'tax' => tax,
                'due' => invoice.dig('due_date'),
                'mail' => invoice.dig('status')&.select { |a| a.keys.include?('mail_delivered') }&.first,
              }.tap do |r|
                if mode == 'full'
                  r['settled'] = invoice.dig('settled', 'amount')
                  r['settle_date'] = invoice.dig('settled', 'date')
                end
              end
            end
            stat['issue_date'] = scan_date.to_s
            stat['count'] = stat['records'].count
            stat['total'] = stat['records'].inject(0) { |sum, rec| sum + rec.dig('subtotal') }
            stat['tax'] = stat['records'].inject(0) { |sum, rec| sum + rec.dig('tax') }
            collection << readable(stat)
          end
        end
      end
    end

    # send payment list to preview address or from address.
    #
    def stats_email(count = 3, mode: nil)
      {}.tap do |res|
        stats(count, mode: mode).each.with_index(1) do |stat, i|
          stat['records'].each do |record|
            res[record['customer']] ||= {}
            res[record['customer']]['customer_name'] ||= record['customer']
            res[record['customer']]["amount#{i}"] ||= record['subtotal'].to_s
            res[record['customer']]["tax#{i}"] ||= record['tax']
            next if mode != 'full' || ! record['settled']

            diff = ['subtotal', 'tax', 'settled'].map { |k| record[k] }.compact.sum
            mark = if diff == 0
                     '[S]'
                   elsif diff > 0
                     '[P]'
                   else
                     '[O]'
                   end
            res[record['customer']]["amount#{i}"].insert(0, mark)
          end
          if i == 1
            @issue_date = stat['issue_date']
            @total_amount = stat['total']
            @total_tax = stat['tax']
            @total_count = stat['count']
          end
        end
        @invoices = res.values
      end
      @company = LucaRecord::CONST.config.dig('company', 'name')
      @legend = if mode == 'full'
                  '[S] Settled, [P] Partially settled, [O] Overpaid'
                else
                  ''
                end
      @unsettled = if mode == 'full'
                     self.class.report(@date)
                   else
                     []
                   end

      mail = Mail.new
      mail.to = LucaRecord::CONST.config.dig('mail', 'preview') || LucaRecord::CONST.config.dig('mail', 'from')
      mail.subject = 'Check monthly payment list'
      mail.html_part = Mail::Part.new(body: render_erb(search_template('monthly-payment-list.html.erb')), content_type: 'text/html; charset=UTF-8')
      LucaSupport::Mail.new(mail, LucaRecord::CONST.pjdir).deliver
    end

    def export_json
      labels = export_labels
      [].tap do |res|
        self.class.asof(@date.year, @date.month) do |dat|
          item = {}
          item['date'] = dat['issue_date']
          item['debit'] = []
          item['credit'] = []
          dat['subtotal'].map do |sub|
            if readable(sub['items']) != 0
              item['debit'] << { 'label' => labels[:debit][:items], 'amount' => readable(sub['items']) }
              item['credit'] << { 'label' => labels[:credit][:items], 'amount' => readable(sub['items']) }
            end
            if readable(sub['tax']) != 0
              item['debit'] << { 'label' => labels[:debit][:tax], 'amount' => readable(sub['tax']) }
              item['credit'] << { 'label' => labels[:credit][:tax], 'amount' => readable(sub['tax']) }
            end
          end
          item['x-customer'] = dat['customer']['name'] if dat.dig('customer', 'name')
          item['x-editor'] = 'LucaDeal'
          res << item
        end
        puts JSON.dump(res)
      end
    end

    def single_invoice(contract_id)
      contract = Contract.find(contract_id)
      raise "Invoice already exists for #{contract_id}. exit" if duplicated_contract? contract['id']

      gen_invoice!(invoice_object(contract))
    end

    def monthly_invoice(target = 'monthly')
      Contract.new(@date.to_s).active do |contract|
        next if contract.dig('terms', 'billing_cycle') != target
        # TODO: provide another I/F for force re-issue if needed
        next if duplicated_contract? contract['id']

        gen_invoice!(invoice_object(contract))
      end
    end

    def invoice_object(contract)
      {}.tap do |invoice|
        invoice['contract_id'] = contract['id']
        invoice['customer'] = get_customer(contract.dig('customer_id'))
        invoice['due_date'] = due_date(@date)
        invoice['issue_date'] = @date
        invoice['sales_fee'] = contract['sales_fee'] if contract.dig('sales_fee')
        invoice['items'] = get_products(contract['products'])
                             .concat(contract['items']&.map { |i| i['qty'] ||= 1; i } || [])
                             .compact
        invoice['items'].reject! do |item|
          item.dig('type') == 'initial' && subsequent_month?(contract.dig('terms', 'effective'))
        end
        invoice['subtotal'] = subtotal(invoice['items'])
                                .map { |k, v| v.tap { |dat| dat['rate'] = k } }
      end
    end

    def get_customer(id)
      {}.tap do |res|
        Customer.find(id) do |dat|
          customer = parse_current(dat)
          res['id'] = customer['id']
          res['name'] = customer.dig('name')
          res['address'] = customer.dig('address')
          res['address2'] = customer.dig('address2')
          res['to'] = customer.dig('contacts').map { |h| take_current(h, 'mail') }.compact
        end
      end
    end

    def get_products(products)
      return [] if products.nil?

      [].tap do |res|
        products.each do |product|
          Product.find(product['id'])['items'].each do |item|
            item['product_id'] = product['id']
            item['qty'] ||= 1
            res << item
          end
        end
      end
    end

    def gen_invoice!(invoice)
      id = invoice.dig('contract_id')
      self.class.create(invoice, date: @date, codes: Array(id))
    end

    def issue_date(date)
      base =  date.nil? ? Date.today : Date.parse(date)
      Date.new(base.year, base.month, -1)
    end

    # TODO: support due_date variation
    def due_date(date)
      next_month = date.next_month
      Date.new(next_month.year, next_month.month, -1)
    end

    private

    # set variables for ERB template
    #
    def invoice_vars(invoice_dat, sample = false)
      @customer = sample ? @company : invoice_dat['customer']
      @items = readable(invoice_dat['items'])
      @subtotal = readable(invoice_dat['subtotal'])
      @issue_date = invoice_dat['issue_date']
      @due_date = invoice_dat['due_date']
      @amount = readable(invoice_dat['subtotal'].inject(0) { |sum, i| sum + i['items'] + i['tax'] })
    end

    def deliver_one(invoice, path, mode: nil, attachment_type: nil)
      attachment_type ||= LucaRecord::CONST.config.dig('invoice', 'attachment') || :html
      mail = compose_mail(invoice, mode: mode, attachment: attachment_type.to_sym)
      LucaSupport::Mail.new(mail, LucaRecord::CONST.pjdir).deliver
      self.class.add_status!(path, 'mail_delivered') if mode.nil?
    end

    def lib_path
      __dir__
    end

    # TODO: load labels from LucaRecord::CONST.config before country defaults
    #
    def export_labels
      case LucaRecord::CONST.config['country']
      when 'jp'
        {
          debit: { items: '売掛金', tax: '売掛金' },
          credit: { items: '売上高', tax: '売上高' }
        }
      else
        {
          debit: { items: 'Accounts receivable - trade', tax: 'Accounts receivable - trade' },
          credit: { items: 'Amount of Sales', tax: 'Amount of Sales' }
        }
      end
    end

    # load user company profile from config.
    #
    def set_company
      {}.tap do |h|
        h['name'] = LucaRecord::CONST.config.dig('company', 'name')
        h['address'] = LucaRecord::CONST.config.dig('company', 'address')
        h['address2'] = LucaRecord::CONST.config.dig('company', 'address2')
      end
    end

    # calc items & tax amount by tax category
    #
    def subtotal(items)
      {}.tap do |subtotal|
        items.each do |i|
          rate = i.dig('tax') || 'default'
          qty = i['qty'] || BigDecimal('1')
          subtotal[rate] = { 'items' => 0, 'tax' => 0 } if subtotal.dig(rate).nil?
          subtotal[rate]['items'] += i['price'] * qty
        end
        subtotal.each do |rate, amount|
          amount['tax'] = (amount['items'] * load_tax_rate(rate))
        end
      end
    end

    # load Tax Rate from config.
    #
    def load_tax_rate(name)
      return 0 if LucaRecord::CONST.config.dig('tax_rate', name).nil?

      BigDecimal(take_current(LucaRecord::CONST.config['tax_rate'], name).to_s)
    end

    def attachment_name(dat, type)
      id = %r{/}.match(dat['id']) ? dat['id'].gsub('/', '') : dat['id'][0, 7]
      "invoice-#{id}.#{type}"
    end

    def duplicated_contract?(id)
      self.class.asof(@date.year, @date.month, @date.day) do |_f, path|
        return true if path.include?(id)
      end
      false
    end

    def subsequent_month?(effective_date)
      effective_date = Date.parse(effective_date) unless effective_date.respond_to? :year
      effective_date.year != @date.year || effective_date.month != @date.month
    end
  end
end
