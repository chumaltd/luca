# frozen_string_literal: true

require 'luca_support/code'
require 'luca_support/config'
require 'luca_record/dict'
require 'luca_record/io'
require 'luca_book'
require 'date'
require 'pathname'

module LucaBook
  class Dict < LucaRecord::Dict
    include Accumulator
    include LucaRecord::IO

    @dirname = 'journals'
    @record_type = 'raw'
    # Column number settings for CSV/TSV convert
    #
    # :label
    #   for double entry data
    # :counter_label
    #   must be specified with label
    # :debit_label
    #   for double entry data
    # * debit_amount
    # :credit_label
    #   for double entry data
    # * credit_amount
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
        config[:debit_amount] = @config['debit_amount'].to_i if @config.dig('debit_amount')
        config[:credit_amount] = @config['credit_amount'].to_i if @config.dig('credit_amount')
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

    # Find balance at financial year start by given date.
    # If not found 'start-yyyy-mm-*.tsv', use 'start.tsv' as default.
    #
    def self.latest_balance(date)
      load_tsv_dict(latest_balance_path(date))
    end

    def self.latest_balance_path(date)
      start_year = date.month >= LucaSupport::CONFIG['fy_start'] ? date.year : date.year - 1
      latest = Date.new(start_year, LucaSupport::CONFIG['fy_start'], 1).prev_month
      dict_dir = Pathname(LucaSupport::PJDIR) / 'data' / 'balance'
      fileglob = %Q(start-#{latest.year}-#{format("%02d", latest.month)}-*)
      path = Dir.glob(fileglob, base: dict_dir)[0] || 'start.tsv'
      dict_dir / path
    end

    def self.issue_date(obj)
      Date.parse(obj.dig('_date', :label))
    end

    def self.generate_balance(year)
      start_date = Date.new((year.to_i - 1), LucaSupport::CONFIG['fy_start'], 1)
      end_date = Date.new(year.to_i, LucaSupport::CONFIG['fy_start'] - 1, -1)
      labels = load('base.tsv')
      bs = load_balance(start_date, end_date)
      fy_digest = checksum(start_date, end_date)
      current_ref = gitref
      csv = CSV.generate(String.new, col_sep: "\t", headers: false) do |f|
        f << ['code', 'label', 'balance']
        f << ['_date', end_date]
        f << ['_digest', fy_digest]
        f << ['_gitref', current_ref] if current_ref
        bs.each do |code, balance|
          f << [code, labels.dig(code, :label), LucaSupport::Code.readable(balance)]
        end
      end
      dict_dir = Pathname(LucaSupport::PJDIR) / 'data' / 'balance'
      filepath = dict_dir / "start-#{end_date.to_s}.tsv"

      File.open(filepath, 'w') { |f| f.write csv }
    end

    def self.load_balance(start_date, end_date)
      base = latest_balance(start_date).each_with_object({}) do |(k, v), h|
        h[k] = BigDecimal(v[:balance].to_s) if v[:balance]
      end

      search_range = term_by_month(start_date, end_date)
      bs = search_range.each_with_object(base) do |date, h|
        net(date.year, date.month)[0].each do |code, amount|
          next if /^[^1-9]/.match(code)

          h[code] ||= BigDecimal('0')
          h[code] += amount
        end
      end
      bs['9142'] ||= BigDecimal('0')
      bs['9142'] += LucaBook::State
                     .range(start_date.year, start_date.month, end_date.year, end_date.month)
                     .net_income
      bs.sort
    end

    def self.checksum(start_date, end_date)
      digest = update_digest(String.new, File.read(latest_balance_path(start_date)))
      term_by_month(start_date, end_date)
        .map { |date| dir_digest(date.year, date.month) }
        .each { |month_digest| digest = update_digest(digest, month_digest) }
      digest
    end

    def self.gitref
      digest = `git rev-parse HEAD`
      $?.exitstatus == 0 ? digest.strip : nil
    end

    def self.term_by_month(start_date, end_date)
      Enumerator.new do |yielder|
        each_month = start_date
        while each_month <= end_date
          yielder << each_month
          each_month = each_month.next_month
        end
      end
    end
  end
end
