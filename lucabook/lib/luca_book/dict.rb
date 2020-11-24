# frozen_string_literal: true

require 'luca_support/config'
require 'luca_record/dict'
require 'date'
require 'pathname'

module LucaBook
  class Dict < LucaRecord::Dict
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

    def search(word, default_word = nil)
      res = super(word, default_word)
      case res
      when Hash
        options = {}.tap do |opt|
          opt[:tax_options] = res['tax_options'] if res['tax_options']
        end
        [res['account_label'], options]
      else
        [res, nil]
      end
    end

    def self.latest_balance
      dict_dir = Pathname(LucaSupport::Config::Pjdir) / 'data' / 'balance'
      # TODO: search latest balance dictionary
      load_tsv_dict(dict_dir / 'start.tsv')
    end

    def self.issue_date(obj)
      Date.parse(obj.dig('_date', :label))
    end
  end
end
