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

    def search(word, default_word = nil, amount = nil)
      res = super(word, default_word, main_key: 'account_label')
      if res.is_a?(Array) && res[0].is_a?(Array)
        filter_amount(res, amount)
      else
        res
      end
    end

    # Choose setting on Big or small condition.
    #
    def filter_amount(settings, amount = nil)
      return settings[0] if amount.nil?

      settings.each do |item|
        return item unless item[1].keys.include?(:on_amount)

        condition = item.dig(1, :on_amount)
        case condition[0]
        when '>'
          return item if amount > BigDecimal(condition[1..])
        when '<'
          return item if amount < BigDecimal(condition[1..])
        else
          return item
        end
      end
      nil
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
