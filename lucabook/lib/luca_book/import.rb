# frozen_string_literal: true

require 'date'
require 'json'
require 'luca_book'
require 'luca_support'
require 'luca_record'

begin
  require "luca_book/import_#{LucaSupport::CONFIG['country']}"
rescue LoadError => e
  e.message
end

module LucaBook
  class Import
    DEBIT_DEFAULT = '10XX'
    CREDIT_DEFAULT = '50XX'

    def initialize(path, dict)
      raise 'no such file' unless FileTest.file?(path)

      @target_file = path
      # TODO: yaml need to be configurable
      @dict_name = dict
      @dict = LucaBook::Dict.new("import-#{dict}.yaml")
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
    #           "amount": 20000
    #         }
    #       ],
    #       "credit" : [
    #         {
    #           "label": "trade notes receivable",
    #           "amount": 20000
    #         }
    #       ],
    #       "note": "settlement for the last month trade"
    #     }
    #   ]
    #
    def self.import_json(io)
      JSON.parse(io).each do |d|
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

    private

    # convert single entry data
    #
    def parse_single(row)
      if (row.dig(@config[:credit_amount]) || []).empty?
        amount = BigDecimal(row[@config[:debit_amount]])
        debit = true
      else
        amount = BigDecimal(row[@config[:credit_amount]])
      end
      default_label = debit ? (@config.dig(:default_debit) || DEBIT_DEFAULT) : (@config.dig(:default_credit) || CREDIT_DEFAULT)
      code, options = search_code(row[@config[:label]], default_label, amount)
      counter_code = @code_map.dig(@config[:counter_label])
      if options
        x_customer = options[:'x-customer'] if options[:'x-customer']
        data, data_c = tax_extension(code, counter_code, amount, options) if respond_to? :tax_extension
      end
      data ||= [{ 'code' => code, 'amount' => amount }]
      data_c ||= [{ 'code' => counter_code, 'amount' => amount }]
      {}.tap do |d|
        d['date'] = parse_date(row)
        if debit
          d['debit'] = data
          d['credit'] = data_c
        else
          d['debit'] = data_c
          d['credit'] = data
        end
        d['note'] = Array(@config[:note]).map{ |col| row[col] }.join(' ')
        d['headers'] = { 'x-editor' => "LucaBook::Import/#{@dict_name}" }
        d['headers']['x-customer'] = x_customer if x_customer
      end
    end

    # convert double entry data
    #
    def parse_double(row)
      {}.tap do |d|
        d['date'] = parse_date(row)
        d['debit'] = {
          'code' => search_code(row[@config[:label]], @config.dig(:default_debit)) || DEBIT_DEFAULT,
          'amount' => row.dig(@config[:debit_amount])
        }
        d['credit'] = {
          'code' => search_code(row[@config[:label]], @config.dig(:default_credit)) || CREDIT_DEFAULT,
          'amount' => row.dig(@config[:credit_amount])
        }
        d['note'] = Array(@config[:note]).map{ |col| row[col] }.join(' ')
        d['x-editor'] = "LucaBook::Import/#{@dict_name}"
      end
    end

    def search_code(label, default_label, amount = nil)
      label, options = @dict.search(label, default_label, amount)
      [@code_map.dig(label), options]
    end

    def parse_date(row)
      return nil if row.dig(@config[:year]).empty?

      "#{row.dig(@config[:year])}-#{row.dig(@config[:month])}-#{row.dig(@config[:day])}"
    end
  end
end
