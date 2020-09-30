# frozen_string_literal: true

require 'date'
require 'json'
require 'luca_book'
require 'luca_support'
#require 'luca_book/dict'
require 'luca_record'

module LucaBook
  class Import
    DEBIT_DEFAULT = '仮払金'
    CREDIT_DEFAULT = '仮受金'

    def initialize(path)
      raise 'no such file' unless FileTest.file?(path)

      @target_file = path
      # TODO: yaml need to be configurable
      @dict = LucaRecord::Dict.new('import.yaml')
      @code_map = LucaRecord::Dict.reverse(LucaRecord::Dict.load('base.tsv'))
      @config = @dict.csv_config
    end

    # === JSON Format:
    #   {
    #     "date": "2020-05-04",
    #     "debit" : [
    #       {
    #         "label": "savings accounts",
    #         "value": 20000
    #       }
    #     ],
    #     "credit" : [
    #       {
    #         "label": "trade notes receivable",
    #         "value": 20000
    #       }
    #     ],
    #     "note": "settlement for the last month trade"
    #   }
    #
    def import_json(io)
      d = JSON.parse(io)
      validate(d)

      # dict = LucaBook::Dict.reverse_dict(LucaBook::Dict::Data)
      d['debit'].each { |h| h['label'] = @dict.search(h['label'], DEBIT_DEFAULT) }
      d['credit'].each { |h| h['label'] = @dict.search(h['label'], CREDIT_DEFAULT) }

      LucaBook.new.create!(d)
    end

    def import_csv
      @dict.load_csv(@target_file) do |row|
        if @config[:type] == 'single'
          LucaBook::Journal.create!(parse_single(row))
        elsif @config[:type] == 'double'
          p parse_double(row)
        else
          p row
        end
      end
    end

    #
    # convert single entry data
    #
    def parse_single(row)
      value = row.dig(@config[:credit_value])&.empty? ? row[@config[:debit_value]] : row[@config[:credit_value]]
      {}.tap do |d| 
        d['date'] = parse_date(row)
        if row.dig(@config[:credit_value])&.empty?
          d['debit'] = [
            { 'label' => search_code(row[@config[:label]], DEBIT_DEFAULT) }
          ]
          d['credit'] = [
            { 'label' => @code_map.dig(@config[:counter_label]) }
          ]
        else
          d['debit'] = [
            { 'label' => @code_map.dig(@config[:counter_label]) }
          ]
          d['credit'] = [
            { 'label' => search_code(row[@config[:label]], CREDIT_DEFAULT) }
          ]
        end
        d['debit'][0]['value'] = value
        d['credit'][0]['value'] = value
        d['note'] = row[@config[:note]]
      end
    end

    #
    # convert double entry data
    #
    def parse_double(row)
      {}.tap do |d|
        d['date'] = parse_date(row)
        d['debit'] = {
          'label' => search_code(row[@config[:debit_label]], DEBIT_DEFAULT),
          'value' => row.dig(@config[:debit_value])
        }
        d['credit'] = {
          'label' => search_code(row[@config[:credit_label]], CREDIT_DEFAULT),
          'value' => row.dig(@config[:credit_value])
        }
        d['note'] = row[@config[:note]]
      end
    end

    def search_code(label, default_label)
      @code_map.dig(@dict.search(label, default_label))
    end

    def parse_date(row)
      return nil if row.dig(@config[:year]).empty?

      "#{row.dig(@config[:year])}-#{row.dig(@config[:month])}-#{row.dig(@config[:day])}"
    end

    def validate(obj)
      raise 'NoDateKey' if ! obj.has_key?('date')
      raise 'NoDebitKey' if ! obj.has_key?('debit')
      raise 'NoDebitValue' if obj['debit'].length < 1
      raise 'NoCreditKey' if ! obj.has_key?('credit')
      raise 'NoCreditValue' if obj['credit'].length < 1
    end
  end
end
