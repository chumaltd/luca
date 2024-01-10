# frozen_string_literal: true

require 'luca_support'
require 'luca_record'

module LucaSalary
  class State < LucaRecord::Base
    include Accumulator

    @dirname = 'payments'

    def initialize(data, count = nil, start_d: nil, end_d: nil)
      @monthly = data
      @count = count
      @start_date = start_d
      @end_date = end_d
      @dict = LucaRecord::Dict.load_tsv_dict(Pathname(LucaRecord::CONST.pjdir) / 'dict' / 'code.tsv')
    end

    def self.range(from_year, from_month, to_year = from_year, to_month = from_month)
      date = Date.new(from_year.to_i, from_month.to_i, -1)
      last_date = Date.new(to_year.to_i, to_month.to_i, -1)
      raise 'invalid term specified' if date > last_date

      counts = []
      reports = [].tap do |r|
        while date <= last_date do
          slips = term(date.year, date.month, date.year, date.month)
          record, count = accumulate(slips)
          r << record.tap { |c| c['_d'] = date.to_s }
          counts << count
          date = Date.new(date.next_month.year, date.next_month.month, -1)
        end
      end
      new(reports, counts,
          start_d: Date.new(from_year.to_i, from_month.to_i, 1),
          end_d: Date.new(to_year.to_i, to_month.to_i, -1)
         )
    end

    def report()
      total, _count = LucaSalary::State.accumulate(@monthly)
      total['_d'] = 'total'
      [@monthly, total].flatten.map do |m|
        {}.tap do |r|
          m.sort.to_h.each do |k, v|
            r["#{@dict.dig(k, :label) || k}"] = readable(v)
          end
        end
      end
    end
  end
end
