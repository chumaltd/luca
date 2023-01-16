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
      @pjdir = Pathname(LucaSupport::PJDIR)
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

    def self.year_total(year)
      Profile.all do |profile|
        id = profile.dig('id')
        payment = { 'profile_id' => id }
        # payment = {}
        (1..12).each do |month|
          search(year, month, nil, id).each do |origin|
            # TODO: to be updated null check
            if origin == {}
              month
            else
              origin.select { |k, _v| /^[1-4][0-9A-Fa-f]{,3}$/.match(k) }.each do |k, v|
                payment[k] = payment[k] ? payment[k] + v : v
              end
              nil
            end
          end
        end
        date = Date.new(year, 12, 31)
        payment = local_convert(payment, date)
        create(payment, date: date, codes: [id], basedir: 'payments/total')
      end
    end

    def self.local_convert(payment, date)
      return payment if CONFIG['country'].nil?

      require "luca_salary/#{CONFIG['country'].downcase}"
      klass = Kernel.const_get("LucaSalary::#{CONFIG['country'].capitalize}")
      klass.year_total(payment, date)
    rescue NameError
      return payment
    end

    # Apply adjustment for yearly refund.
    # Search Year Total records 6 months before specified payslip month.
    #
    def self.year_adjust(year, month)
      target_month = Date.new(year, month, 1)
      total_st = target_month.prev_month(6)
      search(year, month).each do |slip, path|
        term(total_st.year, total_st.month, year, month, slip['profile_id'], "#{@dirname}/total/") do |total|
          slip['3A1'] = total['3A1']
          slip['4A1'] = total['4A1']
        end
        # Recalculate sum
        ['3', '4'].each do |key|
          slip[key] = 0
          slip[key] = LucaSalary::Base.sum_code(slip, key)
          slip['5'] = slip['1'] - slip['2'] - slip['3'] + slip['4']
        end
        IO.write(
          abs_path(@dirname) / path[0] / "#{path[1]}-#{path[2]}",
          YAML.dump(LucaSupport::Code.readable(slip.sort.to_h))
        )
      end
    end

    # Export json for LucaBook.
    # Accrual_date can be change with `payment_term` on config.yml. Default value is 0.
    # `payment_term: 1` means payment on the next month of calculation target.
    #
    def export_json
      accrual_date = if LucaSupport::CONFIG['payment_term']
                       pt = LucaSupport::CONFIG['payment_term']
                       Date.new(@date.prev_month(pt).year, @date.prev_month(pt).month, -1)
                     else
                       Date.new(@date.year, @date.month, -1)
                     end
      h = { debit: {}, credit: {} }
      accumulate.each do |k, v|
        next if @dict.dig(k, :acct_label).nil?

        pos = acct_balance(k)
        acct_label = @dict[k][:acct_label]
        h[pos][acct_label] = h[pos].key?(acct_label) ? h[pos][acct_label] + v : v
      end
      [].tap do |res|
        {}.tap do |item|
          item['date'] = "#{accrual_date.year}-#{accrual_date.month}-#{accrual_date.day}"
          item['debit'] = h[:debit].reject { |_k, v| v.nil? }.map { |k, v| { 'label' => k, 'amount' => v } }
          item['credit'] = h[:credit].reject { |_k, v| v.nil? }.map { |k, v| { 'label' => k, 'amount' => v } }
          item['x-editor'] = 'LucaSalary'
          res << item
        end
        puts JSON.dump(readable(res))
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
