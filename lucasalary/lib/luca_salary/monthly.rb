require 'date'
require 'pathname'
require 'json'
require 'mail'
require 'yaml'
require 'luca'
require 'luca_salary'
require 'luca_salary/fileop'

class Monthly
  include Luca::Code
  include Luca::IO

  def initialize(date = nil)
    @date = parse_date(date)
    @pjdir = set_data_dir(Dir.pwd)
    @salary = Salary.new(date)
  end

  def export_json
    h = {}
    h[:debit] = {}
    h[:credit] = {}
    accumulate.each do |k, v|
      next if @salary.dict.dig(k, :acct_label).nil?

      pos = acct_balance(k)
      acct_label = @salary.dict[k][:acct_label]
      h[pos][acct_label] = h[pos].key?(acct_label) ? h[pos][acct_label] + v : v
    end
    res = {}
    res['date'] = "#{@date.year}-#{@date.month}-#{@date.day}"
    res['debit'] = h[:debit].map { |k, v| { 'label' => k, 'value' => v } }
    res['credit'] = h[:credit].map { |k, v| { 'label' => k, 'value' => v } }
    puts JSON.dump(res)
  end

  def report(mode = nil)
    if mode == 'mail'
      mail = Mail.new do
        subject '[luca salary] Monthly Payment'
      end
      mail.to = @salary.config.dig('mail', 'report_mail')
      mail.text_part = payslip
      Luca::Mail.new(mail, @salary.pjdir).deliver
    else
      puts payslip
    end
  end

  def payslip
    [].tap do |person|
      person << "As of: #{@date.year}/#{@date.month}"

      load_payments do |payment|
        slip = [].tap do |line|
          payment.each do |k, v|
            next if k == 'id'

            line << "#{@salary.dict.dig(k, :label) || k}: #{v}"
          end
        end
        person << slip.join("\n")
      end
    end.join("\n\n")
  end

  def accumulate
    {}.tap do |h|
      load_payments do |payment|
        payment.each do |k, v|
          next if k == 'id'

          h[k] = h.key?(k) ? h[k] + v : v
        end
      end
    end
  end

  def acct_balance(code)
    case code
    when /^1[0-9A-Fa-f]{,3}/
      :debit
    when /^2[0-9A-Fa-f]{,3}/
      :credit
    when /^3[0-9A-Fa-f]{,3}/
      :credit
    when /^4[0-9A-Fa-f]{,3}/
      :debit
    else
      :credit
    end
  end

  def load_payments
    open_payments do |f, name|
      data = YAML.load(f.read)
      yield data
    end
  end

  def open_payments
    payment_dir = Pathname(@pjdir) + 'payments' + "#{@date.year}#{encode_month(@date)}"
    Dir.chdir(payment_dir.to_s) do
      Dir.glob("*").each do |file_name|
        File.open(file_name, 'r') { |f| yield(f, file_name) }
      end
    end
  end

  private

  def parse_date(date = nil)
    date.nil? ? Date.today : Date.parse(date)
  end
end
