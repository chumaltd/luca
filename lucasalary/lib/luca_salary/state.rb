# frozen_string_literal: true

require 'luca_support'
require 'luca_record'

module LucaSalary
  class State < LucaRecord::Base
    @dirname = 'payments'

    def initialize(data, count = nil, start_d: nil, end_d: nil)
      @monthly = data
      @count = count
      @start_date = start_d
      @end_date = end_d
      @dict = LucaRecord::Dict.load_tsv_dict(Pathname(LucaSupport::PJDIR) / 'dict' / 'code.tsv')
    end

    def self.range(from_year, from_month, to_year = from_year, to_month = from_month)
      date = Date.new(from_year.to_i, from_month.to_i, -1)
      last_date = Date.new(to_year.to_i, to_month.to_i, -1)
      raise 'invalid term specified' if date > last_date

      counts = []
      reports = [].tap do |r|
        while date <= last_date do
          record, count = accumulate_term(date.year, date.month)
          r << record.tap { |c| c['_d'] = date.to_s }
          counts << count #.tap { |c| c['_d'] = date.to_s }
          date = Date.new(date.next_month.year, date.next_month.month, -1)
        end
      end
      new(reports, counts,
          start_d: Date.new(from_year.to_i, from_month.to_i, 1),
          end_d: Date.new(to_year.to_i, to_month.to_i, -1)
         )
    end

    def report()
      total = { '_d' => 'total' }
      @monthly.each do |m|
        m.select { |k, _v| /^[1-4][0-9A-Fa-f]{,3}$/.match(k) }.each do |k, v|
          total[k] = total[k] ? total[k] + v : v
        end
      end
      [@monthly, total].flatten.map do |m|
        {}.tap do |r|
          m.sort.to_h.each do |k, v|
            r["#{@dict.dig(k, :label) || k}"] = readable(v)
          end
        end
      end
    end

    def self.accumulate_term(start_year, start_month, end_year = nil, end_month = nil)
      end_year ||= start_year
      end_month ||= start_month
      payment = {}
      count = 0
      term(start_year, start_month, end_year, end_month, nil, @dirname) do |slip, _path|
        count += 1
        slip.select { |k, _v| /^[1-4][0-9A-Fa-f]{,3}$/.match(k) }.each do |k, v|
          payment[k] = payment[k] ? payment[k] + v : v
        end
      end
      [payment, count]
    end
  end
end
