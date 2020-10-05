# frozen_string_literal: true

require 'date'
require 'pathname'
require 'json'
require 'yaml'
require 'luca_salary'
require 'luca_record'

module LucaSalary
  class Payment < LucaRecord::Base
    @dirname = 'payments'

    def initialize(date = nil)
      @date = Date.parse(date)
      @pjdir = Pathname(LucaSupport::Config::Pjdir)
      @dict = LucaRecord::Dict.load_tsv_dict(@pjdir / 'dict' / 'code.tsv')
    end

    #
    # create record with LucaSalary::Profile instance and apyment data
    #
    def create(profile, payment)
      id = profile.dig('id')
      if self.class.search(@date.year, @date.month, @date.day, id).first
        puts "payment record already exists: #{id}"
        return nil
      end

      self.class.gen_record_file!('payments', @date, Array(id)) do |f|
        f.write(YAML.dump(payment.sort.to_h))
      end
    end

    def payslip
      {}.tap do |report|
        report['asof'] = "#{@date.year}/#{@date.month}"
        report['records'] = []

        self.class.asof(@date.year, @date.month) do |payment|
          slip = {}.tap do |line|
            payment.each do |k, v|
              next if k == 'id'

              line["#{@dict.dig(k, :label) || k}"] = v
            end
          end
          report['records'] << slip
        end
      end
    end

    def export_json
      h = {}
      h[:debit] = {}
      h[:credit] = {}
      accumulate.each do |k, v|
        next if @dict.dig(k, :acct_label).nil?

        pos = acct_balance(k)
        acct_label = @dict[k][:acct_label]
        h[pos][acct_label] = h[pos].key?(acct_label) ? h[pos][acct_label] + v : v
      end
      res = {}
      res['date'] = "#{@date.year}-#{@date.month}-#{@date.day}"
      res['debit'] = h[:debit].map { |k, v| { 'label' => k, 'value' => v } }
      res['credit'] = h[:credit].map { |k, v| { 'label' => k, 'value' => v } }
      puts JSON.dump(res)
    end

    private

    def accumulate
      {}.tap do |h|
        self.class.asof(@date.year, @date.month) do |payment|
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
  end
end
