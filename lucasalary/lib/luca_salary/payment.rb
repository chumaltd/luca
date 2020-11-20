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

    def payslip
      {}.tap do |report|
        report['asof'] = "#{@date.year}/#{@date.month}"
        report['payments'] = []
        report['records'] = []

        self.class.asof(@date.year, @date.month) do |payment|
          profile = LucaSalary::Profile.find(payment['profile_id'])
          summary = {
            'name' => profile['name'],
            "#{@dict.dig('5', :label) || '5'}" => payment['5']
          }

          slip = {}.tap do |line|
            line['name'] = profile['name']
            payment.each do |k, v|
              next if k == 'id'

              line["#{@dict.dig(k, :label) || k}"] = v
            end
          end
          report['payments'] << summary
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
      [].tap do |res|
        item = {}
        item['date'] = "#{@date.year}-#{@date.month}-#{@date.day}"
        item['debit'] = h[:debit].map { |k, v| { 'label' => k, 'value' => v } }
        item['credit'] = h[:credit].map { |k, v| { 'label' => k, 'value' => v } }
        item['x-editor'] = 'LucaSalary'
        res << item
        puts JSON.dump(LucaSupport::Code.readable(res))
      end
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
