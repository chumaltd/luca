# frozen_string_literal: true

require 'csv'
require 'pathname'
require 'date'
require 'luca_support'
require 'luca_record'
require 'luca_record/dict'
require 'luca_book'

# Statement on specified term
#
module LucaBook
  class State < LucaRecord::Base
    @dirname = 'journals'
    @record_type = 'raw'

    attr_reader :statement

    def initialize(data, count = nil)
      @data = data
      @count = count
      @dict = LucaRecord::Dict.load('base.tsv')
      @start_balance = set_balance
    end

    # TODO: not compatible with LucaRecord::Base.open_records
    def search_tag(code)
      count = 0
      Dir.children(LucaSupport::Config::Pjdir).sort.each do |dir|
        next if ! FileTest.directory?(LucaSupport::Config::Pjdir+dir)

        open_records(datadir, dir, 3) do |row, i|
          next if i == 2
          count += 1 if row.include?(code)
        end
      end
      puts "#{code}: #{count}"
    end

    def self.term(from_year, from_month, to_year = from_year, to_month = from_month)
      date = Date.new(from_year.to_i, from_month.to_i, -1)
      last_date = Date.new(to_year.to_i, to_month.to_i, -1)
      raise 'invalid term specified' if date > last_date

      counts = []
      reports = [].tap do |r|
        while date <= last_date do
          diff, count = accumulate_month(date.year, date.month)
          r << diff
          counts << count
          date = date.next_month
        end
      end
      new reports, counts
    end

    def by_code(code, year=nil, month=nil)
      raise 'not supported year range yet' if ! year.nil? && month.nil?

      balance = @book.load_start.dig(code) || 0
      full_term = self.class.scan_terms
      if ! month.nil?
        pre_term = full_term.select { |y, m| y <= year.to_i && m < month.to_i }
        balance += pre_term.map { |y, m| self.class.net(y, m)}.inject(0){|sum, h| sum + h[code] }
        [{ code: code, balance: balance, note: "#{code} #{@dict.dig(code, :label)}" }] + records_with_balance(year, month, code, balance)
      else
        start = { code: code, balance: balance, note: "#{code} #{@dict.dig(code, :label)}" }
        full_term.map { |y, m| y }.uniq.map { |y|
          records_with_balance(y, nil, code, balance)
        }.flatten.prepend(start)
      end
    end

    def records_with_balance(year, month, code, balance)
      @book.search(year, month, nil, code).each do |h|
        balance += Util.calc_diff(Util.amount_by_code(h[:debit], code), code) - Util.calc_diff(Util.amount_by_code(h[:credit], code), code)
        h[:balance] = balance
      end
    end

    def to_yaml
      YAML.dump(code2label).tap { |data| puts data }
    end

    def code2label
      @statement ||= @data
      @statement.map do |report|
        {}.tap do |h|
          report.each { |k, v| h[@dict.dig(k, :label)] = v }
        end
      end
    end

    def stats(level = nil)
      keys = @count.map(&:keys).flatten.uniq.sort
      @count.map! do |data|
        keys.each do |k|
          data[k] ||= 0
          next if level.nil? || k.length <= level

          if data[k[0, level]]
            data[k[0, level]] += data[k]
          else
            data[k[0, level]] = data[k]
          end
        end
        data.select! { |k, _v| k.length <= level } if level
        data.sort.to_h
      end
      keys.map! { |k| k[0, level] }.uniq.select! { |k| k.length <= level } if level
      @count.prepend({}.tap { |header| keys.each { |k| header[k] = @dict.dig(k, :label) }})
      puts YAML.dump(@count)
      @count
    end

    def bs(level = 3, legal: false)
      @data.map! { |data| data.select { |k, _v| k.length <= level } }
      @data.map! { |data| code_sum(data).merge(data) } if legal
      base = accumulate_balance(@data)
      length = [base[:debit].length, base[:credit].length].max
      @statement = [].tap do |a|
        length.times do |i|
          {}.tap do |res|
            res['debit_label'] = base[:debit][i] ? @dict.dig(base[:debit][i].keys[0], :label) : ''
            res['debit_balance'] = base[:debit][i] ? @start_balance.dig(base[:debit][i].keys[0]) + base[:debit][i].values[0] : ''
            res['debit_diff'] = base[:debit][i] ? base[:debit][i].values[0] : ''
            res['credit_label'] = base[:credit][i] ? @dict.dig(base[:credit][i].keys[0], :label) : ''
            res['credit_balance'] = base[:credit][i] ? @start_balance.dig(base[:credit][i].keys[0]) + base[:credit][i].values[0] : ''
            res['credit_diff'] = base[:credit][i] ? base[:credit][i].values[0] : ''
            a << res
          end
        end
      end
      puts YAML.dump(@statement)
      self
    end

    def accumulate_balance(monthly_diffs)
      data = monthly_diffs.each_with_object({}) do |month, h|
        month.each do |k, v|
          h[k] = h[k].nil? ? v : h[k] + v
        end
      end.sort.to_h
      { debit: [], credit: [] }.tap do |res|
        data.each do |k, v|
          case k
          when /^[0-4].*/
            res[:debit] << { k => v }
          when /^[5-9H].*/
            res[:credit] << { k => v }
          end
        end
      end
    end

    def pl
      @statement = @data.map { |data| data.select { |k, _v| /^[A-H].+/.match(k) } }
      @statement << @statement.each_with_object({}) { |item, h| item.each { |k, v| h[k].nil? ? h[k] = v : h[k] += v } }
      self
    end

    def self.accumulate_month(year, month)
      monthly_record, count = net(year, month)
      [total_subaccount(monthly_record), count]
    end

    # Accumulate Level 2, 3 account.
    #
    def self.total_subaccount(report)
      {}.tap do |res|
        res['10'] = sum_matched(report, /^[123][0-9A-Z]{2,}/)
        res['40'] = sum_matched(report, /^[4][0-9A-Z]{2,}/)
        res['50'] = sum_matched(report, /^[56][0-9A-Z]{2,}/)
        res['70'] = sum_matched(report, /^[78][0-9A-Z]{2,}/)
        res['8ZZ'] = res['50'] + res['70']
        res['9ZZ'] = sum_matched(report, /^[9][0-9A-Z]{2,}/)
        res['A0'] = sum_matched(report, /^[A][0-9A-Z]{2,}/)
        res['B0'] = sum_matched(report, /^[B][0-9A-Z]{2,}/)
        res['BA'] = res['A0'] - res['B0']
        res['C0'] = sum_matched(report, /^[C][0-9A-Z]{2,}/)
        res['CA'] = res['BA'] - res['C0']
        res['D0'] = sum_matched(report, /^[D][0-9A-Z]{2,}/)
        res['E0'] = sum_matched(report, /^[E][0-9A-Z]{2,}/)
        res['EA'] = res['CA'] + res['D0'] - res['E0']
        res['F0'] = sum_matched(report, /^[F][0-9A-Z]{2,}/)
        res['G0'] = sum_matched(report, /^[G][0-9A-Z]{2,}/)
        res['GA'] = res['EA'] + res['F0'] - res['G0']
        res['HA'] = res['GA'] - sum_matched(report, /^[H][0-9A-Z]{2,}/)

        res['1'] = res['10'] + res['40']
        res['5'] = res['8ZZ'] + res['9ZZ'] + res['HA']

        report.each do |k, v|
          if k.length >= 4
            if res[k[0, 3]]
              res[k[0, 3]] += v
            else
              res[k[0, 3]] = v
            end
          end
        end
        res.sort.to_h
      end
    end

    def code_sum(report)
      legal_items.each.with_object({}) do |k, h|
        h[k] = self.class.sum_matched(report, /^#{k}.*/)
      end
    end

    def set_balance
      base = Dict.latest_balance.each_with_object({}) do |(k, v), h|
        h[k] = v[:balance].to_i if v[:balance]
      end
      code_sum(base).merge(self.class.total_subaccount(base))
    end

    def self.sum_matched(report, reg)
      report.select { |k, v| reg.match(k)}.values.sum
    end

    # for assert purpose
    def self.gross(year, month = nil, code = nil, date_range = nil, rows = 4)
      if ! date_range.nil?
        raise if date_range.class != Range
        # TODO: date based range search
      end

      sum = { debit: {}, credit: {}, debit_count: {}, credit_count: {} }
      idx_memo = []
      asof(year, month) do |f, _path|
        CSV.new(f, headers: false, col_sep: "\t", encoding: 'UTF-8')
          .each_with_index do |row, i|
          break if i >= rows
          case i
          when 0
            idx_memo = row.map(&:to_s)
            idx_memo.each do |r|
              sum[:debit][r] ||= 0
              sum[:debit_count][r] ||= 0
            end
          when 1
            row.each_with_index do |r, j|
              sum[:debit][idx_memo[j]] += r.to_i # TODO: bigdecimal support
              sum[:debit_count][idx_memo[j]] += 1
            end
          when 2
            idx_memo = row.map(&:to_s)
            idx_memo.each do |r|
              sum[:credit][r] ||= 0
              sum[:credit_count][r] ||= 0
            end
          when 3
            row.each_with_index do |r, j|
              sum[:credit][idx_memo[j]] += r.to_i # TODO: bigdecimal support
              sum[:credit_count][idx_memo[j]] += 1
            end
          else
            puts row # for debug
          end
        end
      end
      sum
    end

    # netting vouchers in specified term
    def self.net(year, month = nil, code = nil, date_range = nil)
      g = gross(year, month, code, date_range)
      idx = (g[:debit].keys + g[:credit].keys).uniq.sort
      count = {}
      diff = {}.tap do |sum|
        idx.each do |code|
          sum[code] = g.dig(:debit, code).nil? ? 0 : Util.calc_diff(g[:debit][code], code)
          sum[code] -= g.dig(:credit, code).nil? ? 0 : Util.calc_diff(g[:credit][code], code)
          count[code] = (g.dig(:debit_count, code) || 0) + (g.dig(:credit_count, code) || 0)
        end
      end
      [diff, count]
    end

    # TODO: replace load_tsv -> generic load_tsv_dict
    def load_start
      file = Pathname(LucaSupport::Config::Pjdir) / 'data' / 'balance' / 'start.tsv'
      {}.tap do |dic|
        load_tsv(file) do |row|
          dic[row[0]] = row[2].to_i if ! row[2].nil?
        end
      end
    end

    def load_tsv(path)
      return enum_for(:load_tsv, path) unless block_given?

      data = CSV.read(path, headers: true, col_sep: "\t", encoding: 'UTF-8')
      data.each { |row| yield row }
    end

    private

    def legal_items
      return [] unless LucaSupport::Config::COUNTRY

      case LucaSupport::Config::COUNTRY
      when 'jp'
        ['91', '911', '912', '913', '9131', '9132', '914', '9141', '9142', '915', '916', '92', '93']
      end
    end
  end
end
