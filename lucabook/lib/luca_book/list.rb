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

    def initialize(data)
      @data = data
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
      new data
    end

    def convert_label
      @data.each do |dat|
        dat[:debit].each { |debit| debit[:code] = "#{debit[:code]} #{@dict.dig(debit[:code], :label)}" }
        dat[:credit].each { |credit| credit[:code] = "#{credit[:code]} #{@dict.dig(credit[:code], :label)}" }
      end
      self
    end

    def flat_list
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
      self
    end

    def to_yaml
      YAML.dump(LucaSupport::Code.readable(@data)).tap { |data| puts data }
    end

    def dict
      LucaBook::Dict::Data
    end
  end
end
