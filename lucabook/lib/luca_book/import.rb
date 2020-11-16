# frozen_string_literal: true

require 'date'
require 'json'
require 'luca_book'
require 'luca_support'
#require 'luca_book/dict'
require 'luca_record'

module LucaBook
  class Import
    DEBIT_DEFAULT = '10XX'
    CREDIT_DEFAULT = '50XX'

    def initialize(path, dict)
      raise 'no such file' unless FileTest.file?(path)

      @target_file = path
      # TODO: yaml need to be configurable
      @dict_name = dict
      @dict = LucaRecord::Dict.new("import-#{dict}.yaml")
      @code_map = LucaRecord::Dict.reverse(LucaRecord::Dict.load('base.tsv'))
      @config = @dict.csv_config if dict
    end

    # === JSON Format:
    #   [
    #     {
    #       "date": "2020-05-04",
    #       "debit" : [
    #         {
    #           "label": "savings accounts",
    #           "value": 20000
    #         }
    #       ],
    #       "credit" : [
    #         {
    #           "label": "trade notes receivable",
    #           "value": 20000
    #         }
    #       ],
    #       "note": "settlement for the last month trade"
    #     }
    #   ]
    #
    def self.import_json(io)
      JSON.parse(io).each do |d|
        validate(d)

        code_map = LucaRecord::Dict.reverse(LucaRecord::Dict.load('base.tsv'))
        d['debit'].each { |h| h['code'] = code_map.dig(h['label']) || DEBIT_DEFAULT }
        d['credit'].each { |h| h['code'] = code_map.dig(h['label']) || CREDIT_DEFAULT }

        LucaBook::Journal.create(d)
      end
    end

    def import_csv
      @dict.load_csv(@target_file) do |row|
        if @config[:type] == 'single'
          LucaBook::Journal.create(parse_single(row))
        elsif @config[:type] == 'double'
          p parse_double(row) # TODO: Not implemented yet
        else
          p row
        end
      end
    end

    def self.validate(obj)
      raise 'NoDateKey' unless obj.key?('date')
      raise 'NoDebitKey' unless obj.key?('debit')
      raise 'NoDebitValue' if obj['debit'].empty?
      raise 'NoCreditKey' unless obj.key?('credit')
      raise 'NoCreditValue' if obj['credit'].empty?
    end

    private

    #
    # convert single entry data
    #
    def parse_single(row)
      value = row.dig(@config[:credit_value])&.empty? ? row[@config[:debit_value]] : row[@config[:credit_value]]
      {}.tap do |d|
        d['date'] = parse_date(row)
        if row.dig(@config[:credit_value])&.empty?
          d['debit'] = [
            { 'code' => search_code(row[@config[:label]], @config.dig(:default_debit)) || DEBIT_DEFAULT }
          ]
          d['credit'] = [
            { 'code' => @code_map.dig(@config[:counter_label]) }
          ]
        else
          d['debit'] = [
            { 'code' => @code_map.dig(@config[:counter_label]) }
          ]
          d['credit'] = [
            { 'code' => search_code(row[@config[:label]], @config.dig(:default_credit)) || CREDIT_DEFAULT }
          ]
        end
        d['debit'][0]['value'] = value
        d['credit'][0]['value'] = value
        d['note'] = Array(@config[:note]).map{ |col| row[col] }.join(' ')
        d['x-editor'] = "LucaBook::Import/#{@dict_name}"
      end
    end

    #
    # convert double entry data
    #
    def parse_double(row)
      {}.tap do |d|
        d['date'] = parse_date(row)
        d['debit'] = {
          'code' => search_code(row[@config[:label]], @config.dig(:default_debit)) || DEBIT_DEFAULT,
          'value' => row.dig(@config[:debit_value])
        }
        d['credit'] = {
          'code' => search_code(row[@config[:label]], @config.dig(:default_credit)) || CREDIT_DEFAULT,
          'value' => row.dig(@config[:credit_value])
        }
        d['note'] = Array(@config[:note]).map{ |col| row[col] }.join(' ')
        d['x-editor'] = "LucaBook::Import/#{@dict_name}"
      end
    end

    def search_code(label, default_label)
      @code_map.dig(@dict.search(label, default_label))
    end

    def parse_date(row)
      return nil if row.dig(@config[:year]).empty?

      "#{row.dig(@config[:year])}-#{row.dig(@config[:month])}-#{row.dig(@config[:day])}"
    end
  end
end
