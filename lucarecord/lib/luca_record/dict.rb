# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'yaml'
require 'pathname'
require 'luca_support'

#
# Low level API
#
module LucaRecord
  class Dict
    include LucaSupport::Code

    def initialize(file = @filename)
      #@path = file
      @path = self.class.dict_path(file)
      set_driver
    end

    def search(word, default_word = nil)
      res = max_score_code(word.gsub(/[[:space:]]/, ''))
      if res[1] > 0.4
        res[0]
      else
        default_word
      end
    end

    #
    # Column number settings for CSV/TSV convert
    #
    # :label
    #   for double entry data
    # :counter_label
    #   must be specified with label
    # :debit_label
    #   for double entry data
    # * debit_value
    # :credit_label
    #   for double entry data
    # * credit_value
    # :note
    #   can be the same column as another label
    #
    # :encoding
    #   file encoding
    #
    def csv_config
      {}.tap do |config|
        if @config.dig('label')
          config[:label] = @config['label'].to_i
          if @config.dig('counter_label')
            config[:counter_label] = @config['counter_label']
            config[:type] = 'single'
          end
        elsif @config.dig('debit_label')
          config[:debit_label] = @config['debit_label'].to_i
          if @config.dig('credit_label')
            config[:credit_label] = @config['credit_label'].to_i
            config[:type] = 'double'
          end
        end
        config[:type] ||= 'invalid'
        config[:debit_value] = @config['debit_value'].to_i if @config.dig('debit_value')
        config[:credit_value] = @config['credit_value'].to_i if @config.dig('credit_value')
        config[:note] = @config['note'] if @config.dig('note')
        config[:encoding] = @config['encoding'] if @config.dig('encoding')

        config[:year] = @config['year'] if @config.dig('year')
        config[:month] = @config['month'] if @config.dig('month')
        config[:day] = @config['day'] if @config.dig('day')
        config[:default_debit] = @config['default_debit'] if @config.dig('default_debit')
        config[:default_credit] = @config['default_credit'] if @config.dig('default_credit')
      end
    end

    #
    # Load CSV with config options
    #
    def load_csv(path)
      CSV.read(path, headers: true, encoding: "#{@config.dig('encoding') || 'utf-8'}:utf-8").each do |row|
        yield row
      end
    end

    #
    # load dictionary data
    #
    def self.load(file = @filename)
      case File.extname(file)
      when '.tsv', '.csv'
        load_tsv_dict(dict_path(file))
      when '.yaml', '.yml'
        YAML.load_file(dict_path(file), **{})
      else
        raise 'cannot load this filetype'
      end
    end

    #
    # generate dictionary from TSV file. Minimum assumption is as bellows:
    # 1st row is converted symbol.
    #
    # * row[0] is 'code'. Converted hash keys
    # * row[1] is 'label'. Should be human readable labels
    # * after row[2] can be app specific data
    #
    def self.load_tsv_dict(path)
      {}.tap do |dict|
        CSV.read(path, headers: true, col_sep: "\t", encoding: 'UTF-8').each do |row|
          {}.tap do |entry|
            row.each do |header, field|
              next if row.index(header).zero?

              entry[header.to_sym] = field unless field.nil?
            end
            dict[row[0]] = entry
          end
        end
      end
    end

    private

    def set_driver
      input = self.class.load(@path)
      @config = input['config']
      @definitions = input['definitions']
    end

    def self.dict_path(filename)
      Pathname(LucaSupport::Config::Pjdir) / 'dict' / filename
    end

    def self.reverse(dict)
      dict.map{ |k, v| [v[:label], k] }.to_h
    end

    def max_score_code(str)
      res = @definitions.map do |k, v|
        [v, LucaSupport.match_score(str, k, 3)]
      end
      res.max { |x, y| x[1] <=> y[1] }
    end
  end
end
