require 'date'
require 'pathname'
require 'json'
require 'mail'
require 'yaml'
require 'luca_support/mail'
require 'luca_salary'
require 'luca_record'

class Monthly < LucaRecord::Base

  def initialize(date = nil)
    @date = parse_date(date)
    @salary = LucaSalary::Base.new(date)
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
      mail.text_part = YAML.dump(payslip)
      LucaSupport::Mail.new(mail, @salary.pjdir).deliver
    else
      puts YAML.dump(payslip)
    end
  end

  def payslip
    {}.tap do |report|
      report['asof'] = "#{@date.year}/#{@date.month}"
      report['records'] = []

      LucaSalary::Payment.asof(@date.year, @date.month) do |payment|
        slip = {}.tap do |line|
          payment.each do |k, v|
            next if k == 'id'

            line["#{@salary.dict.dig(k, :label) || k}"] = v
          end
        end
        report['records'] << slip
      end
    end
  end

  def accumulate
    {}.tap do |h|
      LucaSalary::Payment.asof(@date.year, @date.month) do |payment|
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

  private

  def parse_date(date = nil)
    date.nil? ? Date.today : Date.parse(date)
  end
end
