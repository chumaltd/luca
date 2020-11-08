require 'luca_deal/version'

require 'mail'
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
      @pjdir = Pathname(LucaSupport::Config::Pjdir)
      @config = load_config(@pjdir / 'config.yml')
    end

    def deliver_mail
      attachment_type = @config.dig('invoice', 'attachment') || :html
      self.class.asof(@date.year, @date.month) do |dat, path|
        next if has_status?(dat, 'mail_delivered')

        mail = compose_mail(dat, attachment: attachment_type.to_sym)
        LucaSupport::Mail.new(mail, @pjdir).deliver
        self.class.add_status!(path, 'mail_delivered')
      end
    end

    def preview_mail(attachment_type = nil)
      attachment_type ||= @config.dig('invoice', 'attachment') || :html
      self.class.asof(@date.year, @date.month) do |dat, _path|
        mail = compose_mail(dat, mode: :preview, attachment: attachment_type.to_sym)
        LucaSupport::Mail.new(mail, @pjdir).deliver
      end
    end

    def compose_mail(dat, mode: nil, attachment: :html)
      @company = set_company
      invoice_vars(dat)

      mail = Mail.new
      mail.to = dat.dig('customer', 'to') if mode.nil?
      mail.subject = @config.dig('invoice', 'mail_subject') || 'Your Invoice is available'
      if mode == :preview
        mail.cc = @config.dig('mail', 'preview') || @config.dig('mail', 'from')
        mail.subject = '[preview] ' + mail.subject
      end
      mail.text_part = Mail::Part.new(body: render_erb(search_template('invoice-mail.txt.erb')), charset: 'UTF-8')
      if attachment == :html
        mail.attachments[attachment_name(dat, attachment)] = render_erb(search_template('invoice.html.erb'))
      elsif attachment == :pdf
        mail.attachments[attachment_name(dat, attachment)] = erb2pdf(search_template('invoice.html.erb'))
      end
      mail
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
                'due' => invoice.dig('due_date')
              }
            end
            stat['issue_date'] = scan_date.to_s
            stat['count'] = stat['records'].count
            stat['total'] = stat['records'].inject(0) { |sum, rec| sum + rec.dig('subtotal') }
            stat['tax'] = stat['records'].inject(0) { |sum, rec| sum + rec.dig('tax') }
            collection << stat
          end
        end
        puts YAML.dump(LucaSupport::Code.readable(collection))
      end
    end

    def monthly_invoice
      LucaDeal::Contract.new(@date.to_s).active do |contract|
        next if contract.dig('terms', 'billing_cycle') != 'monthly'
        # TODO: provide another I/F for force re-issue if needed
        next if duplicated_contract? contract['id']

        invoice = {}
        invoice['id'] = issue_random_id
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
        gen_invoice!(invoice)
      end
    end

    # set variables for ERB template
    #
    def invoice_vars(invoice_dat)
      @customer = invoice_dat['customer']
      @items = invoice_dat['items']
      @subtotal = invoice_dat['subtotal']
      @issue_date = invoice_dat['issue_date']
      @due_date = invoice_dat['due_date']
      @amount = @subtotal.inject(0) { |sum, i| sum + i['items'] + i['tax'] }
    end

    def get_customer(id)
      {}.tap do |res|
        LucaDeal::Customer.find(id) do |dat|
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
          LucaDeal::Product.find(product['id'])['items'].each do |item|
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
      Date.new(date.year, date.month + 1, -1)
    end

    private

    def lib_path
      __dir__
    end

    # load user company profile from config.
    #
    def set_company
      {}.tap do |h|
        h['name'] = @config.dig('company', 'name')
        h['address'] = @config.dig('company', 'address')
        h['address2'] = @config.dig('company', 'address2')
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
      return 0 if @config.dig('tax_rate', name).nil?

      BigDecimal(take_current(@config['tax_rate'], name).to_s)
    end

    def attachment_name(dat, type)
      "invoice-#{dat.dig('id')[0, 7]}.#{type}"
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
