# frozen_string_literal: true

require 'pathname'
require 'date'
require 'luca_support'
require 'luca_record'
require 'luca_record/dict'
require 'luca_book'

# Journal List on specified term
#
module LucaBook
  class List < LucaBook::Journal
    @dirname = 'journals'

    def initialize(data, start_date, code = nil)
      @data = data
      @code = code
      @start = start_date
      @dict = LucaRecord::Dict.load('base.tsv')
    end

    def self.term(from_year, from_month, to_year = from_year, to_month = from_month, code: nil, basedir: @dirname)
      data = LucaBook::Journal.term(from_year, from_month, to_year, to_month, code).select do |dat|
        if code.nil?
          true
        else
          [:debit, :credit].map { |key| serialize_on_key(dat[key], :code) }.flatten.include?(code)
        end
      end
      new data, Date.new(from_year.to_i, from_month.to_i, 1), code
    end

    def list_on_code
      calc_code
      convert_label
      @data = [code_header] + @data.map do |dat|
        date, txid = LucaSupport::Code.decode_id(dat[:id])
        {}.tap do |res|
          res['code'] = dat[:code]
          res['date'] = date
          res['no'] = txid
          res['id'] = dat[:id]
          res['diff'] = dat[:diff]
          res['balance'] = dat[:balance]
          res['counter_code'] = dat[:counter_code].length == 1 ? dat[:counter_code].first : dat[:counter_code]
          res['note'] = dat[:note]
        end
      end
      readable(@data)
    end

    def list_journals
      convert_label
      @data = @data.map do |dat|
        date, txid = LucaSupport::Code.decode_id(dat[:id])
        {}.tap do |res|
          res['date'] = date
          res['no'] = txid
          res['id'] = dat[:id]
          res['debit_code'] = dat[:debit].length == 1 ? dat[:debit][0][:code] : dat[:debit].map { |d| d[:code] }
          res['debit_amount'] =  dat[:debit].inject(0) { |sum, d| sum + d[:amount] }
          res['credit_code'] = dat[:credit].length == 1 ? dat[:credit][0][:code] : dat[:credit].map { |d| d[:code] }
          res['credit_amount'] = dat[:credit].inject(0) { |sum, d| sum + d[:amount] }
          res['note'] = dat[:note]
        end
      end
      readable(@data)
    end

    def accumulate_code
      @data.inject(BigDecimal('0')) do |sum, dat|
        sum + Util.diff_by_code(dat[:debit], @code) - Util.diff_by_code(dat[:credit], @code)
      end
    end

    def to_yaml
      YAML.dump(LucaSupport::Code.readable(@data)).tap { |data| puts data }
    end

    private

    def set_balance
      return BigDecimal('0') if @code.nil? || /^[A-H]/.match(@code)

      balance_dict = Dict.latest_balance
      start_balance = BigDecimal(balance_dict.dig(@code.to_s, :balance) || '0')
      start = Dict.issue_date(balance_dict)&.next_month
      last = @start.prev_month
      if last.year >= start.year && last.month >= start.month
        start_balance + self.class.term(start.year, start.month, last.year, last.month, code: @code).accumulate_code
      else
        start_balance
      end
    end

    def calc_code
      @balance = set_balance
      if @code
        balance = @balance
        @data.each do |dat|
          dat[:diff] = Util.diff_by_code(dat[:debit], @code) - Util.diff_by_code(dat[:credit], @code)
          balance += dat[:diff]
          dat[:balance] = balance
          dat[:code] = @code
          counter = dat[:diff] * Util.pn_debit(@code) > 0 ? :credit : :debit
          dat[:counter_code] = dat[counter].map { |d| d[:code] }
        end
      end
      self
    end

    def convert_label
      @data.each do |dat|
        if @code
          dat[:code] = "#{dat[:code]} #{@dict.dig(dat[:code], :label)}"
          dat[:counter_code] = dat[:counter_code].map { |counter| "#{counter} #{@dict.dig(counter, :label)}" }
        else
          dat[:debit].each { |debit| debit[:code] = "#{debit[:code]} #{@dict.dig(debit[:code], :label)}" }
          dat[:credit].each { |credit| credit[:code] = "#{credit[:code]} #{@dict.dig(credit[:code], :label)}" }
        end
      end
      self
    end

    def dict
      LucaBook::Dict::Data
    end

    def code_header
      {}.tap do |h|
        %w[code date no id diff balance counter_code note].each do |k|
          h[k] = k == 'balance' ? @balance : ''
        end
      end
    end
  end
end
