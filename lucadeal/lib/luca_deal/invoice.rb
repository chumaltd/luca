require 'luca_deal/version'

require 'mail'
require 'yaml'
require 'pathname'
require 'bigdecimal'
require 'luca_support/config'
require 'luca'
require 'luca_deal/contract'
require 'luca_record'

module LucaDeal
  class Invoice < LucaRecord::Base
    include Luca::IO

    @dirname = 'invoices'

    def initialize(date = nil)
      @date = issue_date(date)
      @pjdir = Pathname(LucaSupport::Config::Pjdir)
      @config = load_config(@pjdir + 'config.yml')
    end

    def deliver_mail
      attachment_type = @config.dig('invoice', 'attachment') || :html
      self.class.when(@date.year, @date.month) do |dat, path|
        next if has_status?(dat, 'mail_delivered')

        mail = compose_mail(dat, attachment: attachment_type.to_sym)
        Luca::Mail.new(mail, @pjdir).deliver
        self.class.add_status!(path, 'mail_delivered')
      end
    end

    def preview_mail(attachment_type = nil)
      attachment_type ||= @config.dig('invoice', 'attachment') || :html
      self.class.when(@date.year, @date.month) do |dat, _path|
        mail = compose_mail(dat, mode: :preview, attachment: attachment_type.to_sym)
        Luca::Mail.new(mail, @pjdir).deliver
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

    def stats
      {}.tap do |stat|
        stat['issue_date'] = @date.to_s
        stat['records'] = self.class.when(@date.year, @date.month).map do |invoice|
          amount = invoice['items'].inject(0) { |sum, item| sum + item['price'] }
          [invoice['customer']['name'], amount]
        end
        puts YAML.dump(stat)
      end
    end

    def monthly_invoice
      LucaDeal::Contract.active(@date, @pjdir) do |contract|
        next if contract.dig('terms', 'billing_cycle') != 'monthly'
        # TODO: provide another I/F for force re-issue if needed
        next if duplicated_contract? contract['id']

        invoice = {}
        invoice['id'] = issue_random_id
        invoice['contract_id'] = contract['id']
        invoice['customer'] = get_customer(contract.dig('customer_id'))
        invoice['due_date'] = due_date(@date)
        invoice['issue_date'] = @date
        invoice['items'] = contract.dig('items').map do |item|
          {}.tap do |h|
            h['name'] = take_active(item, 'name')
            h['price'] = take_active(item, 'price')
            h['qty'] = take_active(item, 'qty')
          end
        end
        invoice['subtotal'] = subtotal(invoice['items'])
                              .map { |k, v| v.tap { |dat| dat['rate'] = k } }
        gen_invoice!(invoice)
      end
    end

    #
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
        LucaSalary::Customer.find(id) do |dat|
          res['id'] = dat['id']
          res['name'] = take_active(dat, 'name')
          res['address'] = take_active(dat, 'address')
          res['address2'] = take_active(dat, 'address2')
          res['to'] = dat.dig('contacts').map{|h| take_active(h, 'mail')}.compact
        end
      end
    end

    def gen_invoice!(invoice)
      id = invoice.dig('contract_id')
      invoice_dir = (datadir + 'invoices').to_s
      gen_record_file!(invoice_dir, @date, Array(id)) do |f|
        f.write(YAML.dump(invoice.sort.to_h))
      end
    end

    def datadir
      Pathname(@pjdir) + 'data'
    end

    def issue_date(date)
      base =  date.nil? ? Date.today : Date.parse(date)
      Date.new(base.year, base.month, -1)
    end

    # todo: support due_date variation
    def due_date(date)
      Date.new(date.year, date.month + 1, -1)
    end

    private

    def lib_path
      __dir__
    end

    #
    # load user company profile from config.
    #
    def set_company
      {}.tap do |h|
        h['name'] = @config.dig('company', 'name')
        h['address'] = @config.dig('company', 'address')
        h['address2'] = @config.dig('company', 'address2')
      end
    end

    #
    # calc items & tax amount by tax category
    #
    def subtotal(items)
      {}.tap do |subtotal|
        items.each do |i|
          rate = i.dig('tax') || 'default'
          subtotal[rate] = { 'items' => 0, 'tax' => 0 } if subtotal.dig(rate).nil?
          subtotal[rate]['items'] += i['qty'] * i['price']
        end
        subtotal.each do |rate, amount|
          amount['tax'] = (amount['items'] * load_tax_rate(rate)).to_i
        end
      end
    end

    #
    # load Tax Rate from config.
    #
    def load_tax_rate(name)
      return 0 if @config.dig('tax_rate', name).nil?

      BigDecimal(take_active(@config['tax_rate'], name).to_s)
    end

    def attachment_name(dat, type)
      "invoice-#{dat.dig('id')[0, 7]}.#{type.to_s}"
    end

    def duplicated_contract?(id)
      open_invoices do |f, file_name|
        return true if /#{id}/.match(file_name)
      end
      false
    end

    def open_invoices
      match_files = Pathname(@pjdir) / 'data' / 'invoices' / encode_dirname(@date) / "*"
      Dir.glob(match_files.to_s).each do |file_name|
        File.open(file_name, 'r') { |f| yield(f, file_name) }
      end
    end
  end
end
