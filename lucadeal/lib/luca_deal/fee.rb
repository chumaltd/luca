require 'luca_deal/version'

require 'mail'
require 'json'
require 'yaml'
require 'pathname'
require 'bigdecimal'
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
        limit = contract.dig('terms', 'limit')

        fee = {
          'contract_id' => contract['id'],
          'items' => [],
          'sales_fee' => {
            'fee' => 0,
            'tax' => 0,
            'deduction' => 0,
            'deduction_label' => contract.dig('terms', 'deduction_label')
          }
        }
        fee['customer'] = get_customer(contract['customer_id'])
        fee['issue_date'] = @date
        Invoice.asof(@date.year, @date.month) do |invoice|
          next if invoice.dig('sales_fee', 'id') != contract['id']
          next if exceed_limit?(invoice, limit)

          invoice['items'].each do |item|
            rate = item['type'] == 'initial' ? @rate['initial'] : @rate['default']
            fee['items'] << fee_record(invoice, item, rate)
          end
          subtotal(fee['items']).each{ |k, v| fee['sales_fee'][k] += v }
        end
        NoInvoice.asof(@date.year, @date.month) do |no_invoice|
          next if no_invoice.dig('sales_fee', 'id') != contract['id']
          next if exceed_limit?(no_invoice, limit)

          no_invoice['items'].each do |item|
            rate = item['type'] == 'initial' ? @rate['initial'] : @rate['default']
            fee['items'] << fee_record(no_invoice, item, rate)
          end
          subtotal(fee['items']).each{ |k, v| fee['sales_fee'][k] += v }
        end
        deduction_rate = contract.dig('rate', 'deduction')
        fee['sales_fee']['deduction'] = -1 * (fee['sales_fee']['fee'] * deduction_rate).floor if deduction_rate
        self.class.create(fee, date: @date, codes: Array(contract['id']))
      end
    end

    def deliver_mail(attachment_type = nil, mode: nil, skip_no_item: true)
      attachment_type = LucaRecord::CONST.config.dig('fee', 'attachment') || :html
      fees = self.class.asof(@date.year, @date.month)
      raise "No report for #{@date.year}/#{@date.month}" if fees.count.zero?

      fees.each do |dat, path|
        next if has_status?(dat, 'mail_delivered')
        next if skip_no_item && dat['items'].empty?

        mail = compose_mail(dat, mode: mode, attachment: attachment_type.to_sym)
        LucaSupport::Mail.new(mail, LucaRecord::CONST.pjdir).deliver
        self.class.add_status!(path, 'mail_delivered') if mode.nil?
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
      mail.subject = LucaRecord::CONST.config.dig('fee', 'mail_subject') || 'Your Report is available'
      if mode == :preview
        mail.cc = LucaRecord::CONST.config.dig('mail', 'preview') || LucaRecord::CONST.config.dig('mail', 'from')
        mail.subject = '[preview] ' + mail.subject
      end
      mail.text_part = Mail::Part.new(body: render_erb(search_template('fee-report-mail.txt.erb')), charset: 'UTF-8')
      mail.attachments[attachment_name(dat, attachment)] = render_report(attachment)
      mail
    end

    # Output seriarized fee data to stdout.
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
            stat['records'] = self.class.asof(scan_date.year, scan_date.month).map do |fee|
              {
                'customer' => fee.dig('customer', 'name'),
                'client' => fee['items'].map{ |item| item.dig('customer_name') }.join(' / '),
                'subtotal' => fee.dig('sales_fee', 'fee'),
                'tax' => fee.dig('sales_fee', 'tax'),
                'due' => fee.dig('due_date'),
                'mail' => fee.dig('status')&.select { |a| a.keys.include?('mail_delivered') }&.first
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

    def export_json
      labels = export_labels
      [].tap do |res|
        self.class.asof(@date.year, @date.month) do |dat|
          sub = dat['sales_fee']
          next if readable(sub['fee']) == 0 and readable(sub['deduction']) == 0

          item = {
            'date' => dat['issue_date'],
            'debit' => [],
            'credit' => []
          }
          if readable(sub['fee']) != 0
            item['debit'] << { 'label' => labels[:debit][:fee], 'amount' => readable(sub['fee']) }
            item['credit'] << { 'label' => labels[:credit][:fee], 'amount' => readable(sub['fee']) }
          end
          if readable(sub['tax']) != 0
            item['debit'] << { 'label' => labels[:debit][:tax], 'amount' => readable(sub['tax']) }
            item['credit'] << { 'label' => labels[:credit][:tax], 'amount' => readable(sub['tax']) }
          end
          if readable(sub['deduction']) != 0
            item['debit'] << { 'label' => labels[:debit][:deduction], 'amount' => readable(sub['deduction'] * -1) }
            item['credit'] << { 'label' => sub['deduction_label'] || labels[:credit][:deduction], 'amount' => readable(sub['deduction'] * -1) }
          end
          item['x-customer'] = dat['customer']['name'] if dat.dig('customer', 'name')
          item['x-editor'] = 'LucaDeal'
          res << item
        end
        puts JSON.dump(res)
      end
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
      @sales_fee = readable(fee_dat['sales_fee'])
      @issue_date = fee_dat['issue_date']
      @due_date = fee_dat['due_date']
      @amount = readable(fee_dat['sales_fee']
                           .reject{ |k, _v| k == 'deduction_label' }
                           .inject(0) { |sum, (_k, v)| sum + v })
    end

    def lib_path
      __dir__
    end

    # TODO: load labels from CONST.config before country defaults
    #
    def export_labels
      case LucaRecord::CONST.config['country']
      when 'jp'
        {
          debit: { fee: '支払手数料', tax: '支払手数料', deduction: '未払費用' },
          credit: { fee: '未払費用', tax: '未払費用', deduction: '雑収入' }
        }
      else
        {
          debit: { fee: 'Fees and commisions', tax: 'Fees and commisions', deduction: 'Accounts payable - other' },
          credit: { fee: 'Accounts payable - other', tax: 'Accounts payable - other', deduction: 'Miscellaneous income' }
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

    def attachment_name(dat, type)
      id = %r{/}.match(dat['id']) ? dat['id'].gsub('/', '') : dat['id'][0, 7]
      "feereport-#{id}.#{type}"
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
      return 0 if LucaRecord::CONST.config.dig('tax_rate', name).nil?

      BigDecimal(take_current(LucaRecord::CONST.config['tax_rate'], name).to_s)
    end

    # Fees are unique contract_id in each month
    # If update needed, remove the target fee file.
    #
    def duplicated_contract?(id)
      self.class.asof(@date.year, @date.month, @date.day) do |_f, path|
        return true if path.include?(id)
      end
      false
    end

    def fee_record(invoice, item, rate)
      {
        'invoice_id' => invoice['id'],
        'customer_name' => invoice.dig('customer', 'name'),
        'name' => item['name'],
        'price' => item['price'],
        'qty' => item['qty'],
        'fee' => item['price'] * item['qty'] * rate
      }
    end

    def exceed_limit?(invoice, limit)
      return false if limit.nil?

      contract_start = Contract.find(invoice['contract_id']).dig('terms', 'effective')
      contract_start.next_month(limit).prev_day < @date
    end
  end
end
