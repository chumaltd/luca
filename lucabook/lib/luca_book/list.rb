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
  class List < LucaBook::Journal
    @dirname = 'journals'
    @@dict = LucaRecord::Dict.new('base.tsv')
    attr_reader :data

    def initialize(data, start_date, code = nil)
      @data = data
      @code = code
      @start = start_date
    end

    def self.term(from_year, from_month, to_year = from_year, to_month = from_month, code: nil, basedir: @dirname, recursive: false)
      code = search_code(code) if code
      data = LucaBook::Journal.term(from_year, from_month, to_year, to_month, code).select do |dat|
        if code.nil?
          true
        else
          if recursive
            ! [:debit, :credit].map { |key| serialize_on_key(dat[key], :code) }.flatten.select { |idx|  /^#{code}/.match(idx) }.empty?
          else
            [:debit, :credit].map { |key| serialize_on_key(dat[key], :code) }.flatten.include?(code)
          end
        end
      end
      new data, Date.new(from_year.to_i, from_month.to_i, 1), code
    end

    def self.add_header(from_year, from_month, to_year = from_year, to_month = from_month, code: nil, header_key: nil, header_val: nil)
      return nil if code.nil?
      return nil unless Journal::ACCEPTED_HEADERS.include?(header_key)

      term(from_year, from_month, to_year, to_month, code: code)
        .data.each do |journal|
        Journal.add_header(journal, header_key, header_val)
      end
    end

    def list_by_code(recursive = false)
      calc_code(recursive: recursive)
      convert_label
      @data = [code_header] + @data.map do |dat|
        date, txid = LucaSupport::Code.decode_id(dat[:id])
        {}.tap do |res|
          res['code'] = dat[:code].length == 1 ? dat[:code].first : dat[:code]
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
          res['debit_amount'] = dat[:debit].inject(0) { |sum, d| sum + d[:amount] }
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

    def self.search_code(code)
      return code if @@dict.dig(code)

      @@dict.search(code).tap do |new_code|
        if new_code.nil?
          puts "Search word is not matched with labels"
          exit 1
        end
      end
    end

    private

    def set_balance(recursive = false)
      return BigDecimal('0') if @code.nil? || /^[A-H]/.match(@code)

      LucaBook::State.start_balance(@start.year, @start.month, recursive: recursive)[@code] || BigDecimal('0')
    end

    def calc_code(recursive: false)
      @balance = set_balance(recursive)
      if @code
        balance = @balance
        @data.each do |dat|
          dat[:diff] = Util.diff_by_code(dat[:debit], @code) - Util.diff_by_code(dat[:credit], @code)
          balance += dat[:diff]
          dat[:balance] = balance
          target, counter = dat[:diff] * Util.pn_debit(@code) > 0 ? [:debit, :credit] : [:credit, :debit]
          dat[:code] = dat[target].map { |d| d[:code] }
          dat[:counter_code] = dat[counter].map { |d| d[:code] }
        end
      end
      self
    end

    def convert_label
      @data.each do |dat|
        if @code
          dat[:code] = dat[:code].map { |target| "#{target} #{@@dict.dig(target, :label)}" }
          dat[:counter_code] = dat[:counter_code].map { |counter| "#{counter} #{@@dict.dig(counter, :label)}" }
        else
          dat[:debit].each { |debit| debit[:code] = "#{debit[:code]} #{@@dict.dig(debit[:code], :label)}" }
          dat[:credit].each { |credit| credit[:code] = "#{credit[:code]} #{@@dict.dig(credit[:code], :label)}" }
        end
      end
      self
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
