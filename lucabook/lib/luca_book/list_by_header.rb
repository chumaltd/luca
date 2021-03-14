# frozen_string_literal: true

require 'pathname'
require 'date'
require 'luca_support'
require 'luca_record'
require 'luca_record/dict'
require 'luca_book'

module LucaBook #:nodoc:
  # Journal List on specified term
  #
  class ListByHeader < LucaBook::Journal
    @dirname = 'journals'

    def initialize(data, start_date, code = nil, header_name = nil)
      @data = data
      @code = code
      @header = header_name
      @start = start_date
      @dict = LucaRecord::Dict.load('base.tsv')
    end

    def self.term(from_year, from_month, to_year = from_year, to_month = from_month, code: nil, header: nil, basedir: @dirname)
      data = Journal.term(from_year, from_month, to_year, to_month, code).select do |dat|
        if code.nil?
          true
        else
          [:debit, :credit].map { |key| serialize_on_key(dat[key], :code) }.flatten.include?(code)
        end
      end
      new data, Date.new(from_year.to_i, from_month.to_i, 1), code, header
    end

    def list_by_code
      calc_code
      convert_label
      @data = @data.each_with_object([]) do |(k, v), a|
        journals = v.map do |dat|
          date, txid = decode_id(dat[:id])
          {}.tap do |res|
            res['header'] = k
            res['date'] = date
            res['no'] = txid
            res['id'] = dat[:id]
            res['diff'] = dat[:diff]
            res['balance'] = dat[:balance]
            res['counter_code'] = dat[:counter_code].length == 1 ? dat[:counter_code].first : dat[:counter_code]
            res['note'] = dat[:note]
          end
        end
        a << { 'code' => v.last[:code], 'header' => k, 'balance' => v.last[:balance], 'count' => v.count, 'jounals' => journals }
      end
      readable(@data)
    end

    def accumulate_code
      @data.each_with_object({}) do |dat, sum|
        idx = dat.dig(:headers, @header) || 'others'
        sum[idx] ||= BigDecimal('0')
        sum[idx] += Util.diff_by_code(dat[:debit], @code) - Util.diff_by_code(dat[:credit], @code)
      end
    end

    private

    def set_balance
      return BigDecimal('0') if @code.nil? || /^[A-H]/.match(@code)

      balance_dict = Dict.latest_balance(@start)
      start_balance = BigDecimal(balance_dict.dig(@code.to_s, :balance) || '0')
      start = Dict.issue_date(balance_dict)&.next_month
      last = @start.prev_month
      if last.year >= start.year && last.month >= start.month
        #TODO: start_balance to be implemented by header
        self.class.term(start.year, start.month, last.year, last.month, code: @code).accumulate_code
      else
        #start_balance
      end
    end

    def calc_code
      raise 'no account code specified' if @code.nil?

      @balance = set_balance
      balance = @balance
      res = {}
      @data.each do |dat|
        idx = dat.dig(:headers, @header) || 'others'
        balance[idx] ||= BigDecimal('0')
        res[idx] ||= []
        {}.tap do |h|
          h[:id] = dat[:id]
          h[:diff] = Util.diff_by_code(dat[:debit], @code) - Util.diff_by_code(dat[:credit], @code)
          balance[idx] += h[:diff]
          h[:balance] = balance[idx]
          h[:code] = @code
          counter = h[:diff] * Util.pn_debit(@code) > 0 ? :credit : :debit
          h[:counter_code] = dat[counter].map { |d| d[:code] }
          h[:note] = dat[:note]
          res[idx] << h
        end
      end
      @data = res
      self
    end

    def convert_label
      @data.each do |_k, v|
        v.each do |dat|
          raise 'no account code specified' if @code.nil?

          dat[:code] = "#{dat[:code]} #{@dict.dig(dat[:code], :label)}"
          dat[:counter_code] = dat[:counter_code].map { |counter| "#{counter} #{@dict.dig(counter, :label)}" }
        end
      end
      self
    end
  end
end
