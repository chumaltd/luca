# frozen_string_literal: true

require 'luca_support'
require 'luca_record'

module LucaSalary
  # == Total
  # Yearly summary records are stored in 'payments/total' by each profile.
  #
  class Total < LucaRecord::Base
    include Accumulator
    @dirname = 'payments/total'

    attr_reader :slips

    def initialize(year)
      @date = Date.new(year.to_i, 12, -1)
      @slips = Total.search(year, 12).map do |slip|
        slip['profile'] = parse_current(Profile.find_secure(slip['id']))
        slip
      end
      @dict = LucaRecord::Dict.load_tsv_dict(Pathname(LucaSupport::PJDIR) / 'dict' / 'code.tsv')
    end

    def self.accumulator(year)
      Profile.all do |profile|
        id = profile.dig('id')
        slips = term(year, 1, year, 12, id, 'payments')
        payment, _count = accumulate(slips)
        payment['id'] = id
        date = Date.new(year, 12, 31)
        payment = local_convert(payment, date)
        upsert(payment, basedir: "payments/total/#{year}#{LucaSupport::Code.encode_month(12)}")
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
      total_dirs = Array(0..6)
                     .map{ |i| LucaSupport::Code.encode_dirname(Date.new(year, month, 1).prev_month(i)) }
                     .map do |subdir|
        search_path = "#{@dirname}/#{subdir}"
        Dir.exist?(abs_path(search_path)) ? search_path : nil
      end
      total_path = total_dirs.compact.first
      if total_path.nil?
        puts "No Year total directory exists. exit"
        exit 1
      end

      search(year, month, nil, nil, 'payments').each do |slip, path|
        begin
          find(slip['profile_id'], total_path) do |total|
            ['3A1', '4A1'].each { |cd| slip[cd] = total[cd] }
          end
        rescue
          # skip no adjust profile
        end
        # Recalculate sum
        ['3', '4'].each do |key|
          slip[key] = 0
          slip[key] = LucaSalary::Base.sum_code(slip, key)
        end
        slip['5'] = slip['1'] - slip['2'] - slip['3'] + slip['4']
        update_record(
          'payments',
          path,
          YAML.dump(LucaSupport::Code.readable(slip.sort.to_h))
        )
      end
    end
  end
end
