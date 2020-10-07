
require 'csv'
require 'pathname'
require 'date'
require 'luca_support'
require 'luca_record'
require 'luca_record/dict'
require 'luca_book'

#
# Statement on specified term
#
module LucaBook
  class State < LucaRecord::Base
    @dirname = 'journals'
    @record_type = 'raw'

    attr_reader :statement

    def initialize(data)
      @data = data
      @dict = LucaRecord::Dict.load('base.tsv')
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

      reports = [].tap do |r|
        while date <= last_date do
          r << accumulate_month(date.year, date.month)
          date = date.next_month
        end
      end
      new reports
    end

    def by_code(code, year=nil, month=nil)
      raise "not supported year range yet" if ! year.nil? && month.nil?

      bl = @book.load_start.dig(code) || 0
      full_term = scan_terms(LucaSupport::Config::Pjdir)
      if ! month.nil?
        pre_term = full_term.select{|y,m| y <= year.to_i && m < month.to_i }
        bl += pre_term.map{|y,m| self.class.net(y, m)}.inject(0){|sum, h| sum + h[code]}
        [{ code: code, balance: bl, note: "#{code} #{dict.dig(code, :label)}" }] + records_with_balance(year, month, code, bl)
      else
        start = { code: code, balance: bl, note: "#{code} #{dict.dig(code, :label)}" }
        full_term.map {|y, m| y }.uniq.map {|y|
          records_with_balance(y, nil, code, bl)
        }.flatten.prepend(start)
      end
    end

    def records_with_balance(year, month, code, balance)
      @book.search(year, month, nil, code).each do |h|
        balance += self.class.calc_diff(amount_by_code(h[:debit], code), code) - @book.calc_diff(amount_by_code(h[:credit], code), code)
        h[:balance] = balance
      end
    end

    #
    # TODO: useless method. consider to remove
    #
    def accumulate_all
      current = @book.load_start
      target = []
      Dir.chdir(@book.pjdir) do
        net_records = scan_terms(@book.pjdir).map do |year, month|
          target << [year, month]
          accumulate_month(year, month)
        end
        all_keys = net_records.map{|h| h.keys}.flatten.uniq
        net_records.each.with_index(0) do |diff, i|
          all_keys.each {|key| diff[key] = 0 unless diff.has_key?(key)}
          diff.each do |k,v|
            if current[k]
              current[k] += v
            else
              current[k] = v
            end
          end
          f = { target: "#{target[i][0]}-#{target[i][1]}", diff: diff.sort, current: current.sort }
          yield f
        end
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

    def bs
      @statement = @data.map do |data|
        data.select { |k, v| /^[0-9].+/.match(k) }
      end
      self
    end

    def pl
      @statement = @data.map do |data|
        data.select { |k, v| /^[A-F].+/.match(k) }
      end
      self
    end

    def self.accumulate_month(year, month)
      monthly_record = net(year, month)
      total_subaccount(monthly_record)
    end

    def amount_by_code(items, code)
      items
        .select{|item| item.dig(:code) == code }
        .inject(0){|sum, item| sum + item[:amount] }
    end

    def self.total_subaccount(report)
      report.dup.tap do |res|
        report.each do |k, v|
          if k.length >= 4
            if res[k[0, 3]]
              res[k[0, 3]] += v
            else
              res[k[0, 3]] = v
            end
          end
        end
        res['10'] = sum_matched(report, /^[123].[^0]/)
        res['40'] = sum_matched(report, /^[4].[^0]}/)
        res['50'] = sum_matched(report, /^[56].[^0]/)
        res['70'] = sum_matched(report, /^[78].[^0]/)
        res['90'] = sum_matched(report, /^[9].[^0]/)
        res['A0'] = sum_matched(report, /^[A].[^0]/)
        res['B0'] = sum_matched(report, /^[B].[^0]/)
        res['BA'] = res['A0'] - res['B0']
        res['C0'] = sum_matched(report, /^[C].[^0]/)
        res['CA'] = res['BA'] - res['C0']
        res['D0'] = sum_matched(report, /^[D].[^0]/)
        res['E0'] = sum_matched(report, /^[E].[^0]/)
        res['EA'] = res['CA'] + res['D0'] - res['E0']
        res['F0'] = sum_matched(report, /^[F].[^0]/)
        res['G0'] = sum_matched(report, /^[G].[^0]/)
        res['GA'] = res['EA'] + res['F0'] - res['G0']
        res['HA'] = res['GA'] - sum_matched(report, /^[H].[^0]/)
      end
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

      sum = { debit: {}, credit: {} }
      idx_memo = []
      asof(year, month) do |f, _path|
        CSV.new(f, headers: false, col_sep: "\t", encoding: 'UTF-8')
          .each_with_index do |row, i|
          break if i >= rows
          case i
          when 0
            idx_memo = row.map(&:to_s)
            idx_memo.each { |r| sum[:debit][r] ||= 0 }
          when 1
            row.each_with_index { |r, i| sum[:debit][idx_memo[i]] += r.to_i } # TODO: bigdecimal support
          when 2
            idx_memo = row.map(&:to_s)
            idx_memo.each { |r| sum[:credit][r] ||= 0 }
          when 3
            row.each_with_index { |r, i| sum[:credit][idx_memo[i]] += r.to_i } # TODO: bigdecimal support
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
      {}.tap do |sum|
        idx.each do |code|
          sum[code] = g.dig(:debit, code).nil? ? 0 : calc_diff(g[:debit][code], code)
          sum[code] -= g.dig(:credit, code).nil? ? 0 : calc_diff(g[:credit][code], code)
        end
      end
    end

    # TODO: replace load_tsv -> generic load_tsv_dict
    def load_start
      file = LucaSupport::Config::Pjdir + 'start.tsv'
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

    def self.calc_diff(num, code)
      amount = /\./.match(num.to_s) ? BigDecimal(num) : num.to_i
      amount * pn_debit(code.to_s)
    end

    def self.pn_debit(code)
      case code
      when /^[0-4BCEGH]/
        1
      when /^[5-9ADF]/
        -1
      else
        nil
      end
    end

    def dict
      LucaBook::Dict::Data
    end
  end
end
