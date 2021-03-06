require 'luca_deal/version'

require 'mail'
require 'json'
require 'yaml'
require 'pathname'
require 'bigdecimal'
require 'luca_support/config'
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

    # Render HTML to console
    #
    def preview_stdout
      self.class.asof(@date.year, @date.month) do |dat, _|
        @company = set_company
        invoice_vars(dat)
        puts render_invoice
      end
    end

    def compose_mail(dat, mode: nil, attachment: :html)
      @company = set_company
      invoice_vars(dat)

      mail = Mail.new
      mail.to = dat.dig('customer', 'to') if mode.nil?
      mail.subject = CONFIG.dig('invoice', 'mail_subject') || 'Your Invoice is available'
      if mode == :preview
        mail.cc = CONFIG.dig('mail', 'preview') || CONFIG.dig('mail', 'from')
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
    def stats(count = 1)
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
                'mail' => invoice.dig('status')&.select { |a| a.keys.include?('mail_delivered') }&.first
              }
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
    def stats_email
      {}.tap do |res|
        stats(3).each.with_index(1) do |stat, i|
          stat['records'].each do |record|
            res[record['customer']] ||= {}
            res[record['customer']]['customer_name'] ||= record['customer']
            res[record['customer']]["amount#{i}"] ||= record['subtotal']
            res[record['customer']]["tax#{i}"] ||= record['tax']
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
      @company = CONFIG.dig('company', 'name')

      mail = Mail.new
      mail.to = CONFIG.dig('mail', 'preview') || CONFIG.dig('mail', 'from')
      mail.subject = 'Check monthly payment list'
      mail.html_part = Mail::Part.new(body: render_erb(search_template('monthly-payment-list.html.erb')), content_type: 'text/html; charset=UTF-8')
      LucaSupport::Mail.new(mail, PJDIR).deliver
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
    def invoice_vars(invoice_dat)
      @customer = invoice_dat['customer']
      @items = readable(invoice_dat['items'])
      @subtotal = readable(invoice_dat['subtotal'])
      @issue_date = invoice_dat['issue_date']
      @due_date = invoice_dat['due_date']
      @amount = readable(invoice_dat['subtotal'].inject(0) { |sum, i| sum + i['items'] + i['tax'] })
    end

    def deliver_one(invoice, path, mode: nil, attachment_type: nil)
      attachment_type ||= CONFIG.dig('invoice', 'attachment') || :html
      mail = compose_mail(invoice, mode: mode, attachment: attachment_type.to_sym)
      LucaSupport::Mail.new(mail, PJDIR).deliver
      self.class.add_status!(path, 'mail_delivered') if mode.nil?
    end

    def lib_path
      __dir__
    end

    # TODO: load labels from CONFIG before country defaults
    #
    def export_labels
      case CONFIG['country']
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
        h['name'] = CONFIG.dig('company', 'name')
        h['address'] = CONFIG.dig('company', 'address')
        h['address2'] = CONFIG.dig('company', 'address2')
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
      return 0 if CONFIG.dig('tax_rate', name).nil?

      BigDecimal(take_current(CONFIG['tax_rate'], name).to_s)
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
