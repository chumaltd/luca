require 'luca_deal/version'

require 'mail'
require 'yaml'
require 'pathname'
require 'bigdecimal'
require 'luca_support/config'
require 'luca_support/mail'
require 'luca_deal'

module LucaDeal
  class Fee < LucaRecord::Base
    @dirname = 'fees'

    def initialize(date = nil)
      @date = issue_date(date)
    end

    # calculate fee, based on invoices
    #
    def monthly_fee
      Contract.asof(@date.year, @date.month, @date.day) do |contract|
        next if contract.dig('terms', 'category') != 'sales_fee'
        next if duplicated_contract? contract['id']

        @rate = { 'default' => BigDecimal(contract.dig('rate', 'default')) }
        @rate['initial'] = contract.dig('rate', 'initial') ? BigDecimal(contract.dig('rate', 'initial')) : @rate['default']

        fee = { 'contract_id' => contract['id'], 'items' => [] }
        fee['customer'] = get_customer(contract['customer_id'])
        fee['issue_date'] = @date
        Invoice.asof(@date.year, @date.month) do |invoice|
          next if invoice.dig('sales_fee', 'id') != contract['id']

          invoice['items'].each do |item|
            rate = item['type'] == 'initial' ? @rate['initial'] : @rate['default']
            fee['items'] << {
              'invoice_id' => invoice['id'],
              'customer_name' => invoice.dig('customer', 'name'),
              'name' => item['name'],
              'price' => item['price'],
              'qty' => item['qty'],
              'fee' => item['price'] * item['qty'] * rate
            }
          end
          fee['sales_fee'] = subtotal(fee['items'])
        end
        self.class.create(fee, date: @date, codes: Array(contract['id']))
      end
    end

    def deliver_mail(attachment_type = nil, mode: nil)
      attachment_type = CONFIG.dig('fee', 'attachment') || :html
      fees = self.class.asof(@date.year, @date.month)
      raise "No report for #{@date.year}/#{@date.month}" if fees.count.zero?

      fees.each do |dat, path|
        next if has_status?(dat, 'mail_delivered')

        mail = compose_mail(dat, mode: mode, attachment: attachment_type.to_sym)
        LucaSupport::Mail.new(mail, PJDIR).deliver
        self.class.add_status!(path, 'mail_delivered')
      end
    end

    def preview_mail(attachment_type = nil)
      deliver_mail(attachment_type, mode: :preview)
    end

    # Render HTML to console
    #
    def preview_stdout
      self.class.asof(@date.year, @date.month) do |dat, _|
        @company = set_company
        fee_vars(dat)
        puts render_report
      end
    end

    def compose_mail(dat, mode: nil, attachment: :html)
      @company = set_company
      fee_vars(dat)

      mail = Mail.new
      mail.to = dat.dig('customer', 'to') if mode.nil?
      mail.subject = CONFIG.dig('invoice', 'mail_subject') || 'Your Report is available'
      if mode == :preview
        mail.cc = CONFIG.dig('mail', 'preview') || CONFIG.dig('mail', 'from')
        mail.subject = '[preview] ' + mail.subject
      end
      mail.text_part = Mail::Part.new(body: render_erb(search_template('fee-report-mail.txt.erb')), charset: 'UTF-8')
      mail.attachments[attachment_name(dat, attachment)] = render_report(attachment)
      mail
    end

    def render_report(file_type = :html)
      case file_type
      when :html
        render_erb(search_template('fee-report.html.erb'))
      when :pdf
        erb2pdf(search_template('fee-report.html.erb'))
      else
        raise 'This filetype is not supported.'
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

    private

    # set variables for ERB template
    #
    def fee_vars(fee_dat)
      @customer = fee_dat['customer']
      @items = readable(fee_dat['items'])
      @subtotal = readable(fee_dat['subtotal'])
      @issue_date = fee_dat['issue_date']
      @due_date = fee_dat['due_date']
      @amount = readable(fee_dat['subtotal'].inject(0) { |sum, i| sum + i['fee'] + i['tax'] })
    end

    def lib_path
      __dir__
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

    # calc fee & tax amount by tax category
    #
    def subtotal(items)
      { 'fee' => 0, 'tax' => 0 }.tap do |subtotal|
        items.each do |i|
          subtotal['fee'] += i['fee']
        end
        subtotal['tax'] = (subtotal['fee'] * load_tax_rate('default')).to_i
      end
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

    # load Tax Rate from config.
    #
    def load_tax_rate(name)
      return 0 if CONFIG.dig('tax_rate', name).nil?

      BigDecimal(take_current(CONFIG['tax_rate'], name).to_s)
    end

    def duplicated_contract?(id)
      self.class.asof(@date.year, @date.month, @date.day) do |_f, path|
        return true if path.include?(id)
      end
      false
    end
  end
end
