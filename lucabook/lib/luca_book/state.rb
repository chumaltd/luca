# frozen_string_literal: true

require 'cgi/escape'
require 'csv'
require 'mail'
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

    def initialize(data, count = nil, start_d: nil, end_d: nil)
      @data = data
      @count = count
      @dict = LucaRecord::Dict.load('base.tsv')
      @start_date = start_d
      @end_date = end_d
      @start_balance = set_balance
    end

    def self.range(from_year, from_month, to_year = from_year, to_month = from_month)
      date = Date.new(from_year.to_i, from_month.to_i, -1)
      last_date = Date.new(to_year.to_i, to_month.to_i, -1)
      raise 'invalid term specified' if date > last_date

      counts = []
      reports = [].tap do |r|
        while date <= last_date do
          diff, count = accumulate_month(date.year, date.month)
          r << diff.tap { |c| c['_d'] = date.to_s }
          counts << count.tap { |c| c['_d'] = date.to_s }
          date = Date.new(date.next_month.year, date.next_month.month, -1)
        end
      end
      new(reports, counts,
          start_d: Date.new(from_year.to_i, from_month.to_i, 1),
          end_d: Date.new(to_year.to_i, to_month.to_i, -1)
         )
    end

    def self.by_code(code, from_year, from_month, to_year = from_year, to_month = from_month)
      date = Date.new(from_year.to_i, from_month.to_i, -1)
      last_date = Date.new(to_year.to_i, to_month.to_i, -1)
      raise 'invalid term specified' if date > last_date

      reports = [].tap do |r|
        while date <= last_date do
          diff = {}.tap do |h|
            g = gross(date.year, date.month, code: code)
            sum = g.dig(:debit).nil? ? BigDecimal('0') : Util.calc_diff(g[:debit], code)
            sum -= g.dig(:credit).nil? ? BigDecimal('0') : Util.calc_diff(g[:credit], code)
            h['code'] = code
            h['label'] = LucaRecord::Dict.load('base.tsv').dig(code, :label)
            h['net'] = sum
            h['debit_amount'] = g[:debit]
            h['debit_count'] = g[:debit_count]
            h['credit_amount'] = g[:credit]
            h['credit_count'] = g[:credit_count]
            h['_d'] = date.to_s
          end
          r << diff
          date = Date.new(date.next_month.year, date.next_month.month, -1)
        end
      end
      LucaSupport::Code.readable(reports)
    end

    def code2label
      @statement ||= @data
      @statement.map do |report|
        {}.tap do |h|
          report.each { |k, v| h[@dict.dig(k, :label) || k] = v }
        end
      end
    end

    def stats(level = nil)
      keys = @count.map(&:keys).flatten.push('_t').uniq.sort
      @count.map! do |data|
        sum = 0
        keys.each do |k|
          data[k] ||= 0
          sum += data[k] if /^[^_]/.match(k)
          next if level.nil? || k.length <= level

          if data[k[0, level]]
            data[k[0, level]] += data[k]
          else
            data[k[0, level]] = data[k]
          end
        end
        data.select! { |k, _v| k.length <= level } if level
        data['_t'] = sum
        data.sort.to_h
      end
      keys.map! { |k| k[0, level] }.uniq.select! { |k| k.length <= level } if level
      @count.prepend({}.tap { |header| keys.each { |k| header[k] = @dict.dig(k, :label) }})
      @count
    end

    # TODO: pl/bs may not be immutable
    def report_mail(level = 3)
      @company = CONFIG.dig('company', 'name')
      {}.tap do |res|
        pl(level).reverse.each do |month|
          month.each do |k, v|
            res[k] ||= []
            res[k] << v
          end
        end
        @months = res['_d']
        @pl = res.select{ |k,v| k != '_d' }
      end
      @bs = bs

      mail = Mail.new
      mail.to = CONFIG.dig('mail', 'preview') || CONFIG.dig('mail', 'from')
      mail.subject = 'Financial Report available'
      mail.html_part = Mail::Part.new(body: render_erb(search_template('monthly-report.html.erb')), content_type: 'text/html; charset=UTF-8')
      LucaSupport::Mail.new(mail, PJDIR).deliver
    end

    def bs(level = 3, legal: false)
      set_bs(level, legal: legal)
      base = accumulate_balance(@bs)
      rows = [base[:debit].length, base[:credit].length].max
      @statement = [].tap do |a|
        rows.times do |i|
          {}.tap do |res|
            res['debit_label'] = base[:debit][i] ? @dict.dig(base[:debit][i].keys[0], :label) : ''
            res['debit_balance'] = base[:debit][i] ? (@start_balance.dig(base[:debit][i].keys[0]) || 0) + base[:debit][i].values[0] : ''
            res['debit_diff'] = base[:debit][i] ? base[:debit][i].values[0] : ''
            res['credit_label'] = base[:credit][i] ? @dict.dig(base[:credit][i].keys[0], :label) : ''
            res['credit_balance'] = base[:credit][i] ? (@start_balance.dig(base[:credit][i].keys[0]) || 0) + base[:credit][i].values[0] : ''
            res['credit_diff'] = base[:credit][i] ? base[:credit][i].values[0] : ''
            a << res
          end
        end
      end
      readable(@statement)
    end

    def accumulate_balance(data)
      { debit: [], credit: [] }.tap do |res|
        data.sort.to_h.each do |k, v|
          case k
          when /^[0-4].*/
            res[:debit] << { k => v }
          when /^[5-9].*/
            res[:credit] << { k => v }
          end
        end
      end
    end

    def pl(level = 2)
      set_pl(level)
      @statement = @data.map do |data|
        {}.tap do |h|
          @pl.keys.each { |k| h[k] = data[k] || BigDecimal('0') }
        end
      end
      @statement << @pl
      readable(code2label)
    end

    def self.accumulate_term(start_year, start_month, end_year, end_month)
      date = Date.new(start_year, start_month, 1)
      last_date = Date.new(end_year, end_month, -1)
      return nil if date > last_date

      {}.tap do |res|
        diff, _count = net(date.year, date.month, last_date.year, last_date.month)
        diff.each do |k, v|
          next if /^[_]/.match(k)

          res[k] = res[k].nil? ? v : res[k] + v
        end
      end
    end

    def self.accumulate_month(year, month)
      monthly_record, count = net(year, month)
      [total_subaccount(monthly_record), count]
    end

    # Accumulate Level 2, 3 account.
    #
    def self.total_subaccount(report)
      {}.tap do |res|
        res['A0'] = sum_matched(report, /^[A][0-9A-Z]{2,}/)
        res['B0'] = sum_matched(report, /^[B][0-9A-Z]{2,}/)
        res['BA'] = res['A0'] - res['B0']
        res['C0'] = sum_matched(report, /^[C][0-9A-Z]{2,}/)
        res['CA'] = res['BA'] - res['C0']
        res['D0'] = sum_matched(report, /^[D][0-9A-Z]{2,}/)
        res['E0'] = sum_matched(report, /^[E][0-9A-Z]{2,}/)
        res['EA'] = res['CA'] + res['D0'] - res['E0']
        res['F0'] = sum_matched(report, /^[F][0-9A-Z]{2,}/)
        res['G0'] = sum_matched(report, /^[G][0-9][0-9A-Z]{1,}/)
        res['GA'] = res['EA'] + res['F0'] - res['G0']
        res['H0'] = sum_matched(report, /^[H][0-9][0-9A-Z]{1,}/)
        res['HA'] = res['GA'] - res['H0']

        report['9142'] = (report['9142'] || BigDecimal('0')) + res['HA']
        res['9142'] = report['9142']
        res['10'] = sum_matched(report, /^[12][0-9A-Z]{2,}/)
        jp_4v = sum_matched(report, /^[4][V]{2,}/) # deferred assets for JP GAAP
        res['30'] = sum_matched(report, /^[34][0-9A-Z]{2,}/) - jp_4v
        res['4V'] = jp_4v if CONFIG['country'] == 'jp'
        res['50'] = sum_matched(report, /^[56][0-9A-Z]{2,}/)
        res['70'] = sum_matched(report, /^[78][0-9A-Z]{2,}/)
        res['91'] = sum_matched(report, /^91[0-9A-Z]{1,}/)
        res['8ZZ'] = res['50'] + res['70']
        res['9ZZ'] = sum_matched(report, /^[9][0-9A-Z]{2,}/)

        res['1'] = res['10'] + res['30']
        res['5'] = res['8ZZ'] + res['9ZZ']
        res['_d'] = report['_d']

        report.each do |k, v|
          res[k] ||= sum_matched(report, /^#{k}[0-9A-Z]{1,}/) if k.length == 2
          res[k] = v if k.length == 3
        end

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
      pre_last = @start_date.prev_month
      start_year = if @start_date.month > CONFIG['fy_start'].to_i
                     pre_last.year
                   else
                     pre_last.year - 1
                   end
      pre = self.class.accumulate_term(start_year, CONFIG['fy_start'], pre_last.year, pre_last.month)

      base = Dict.latest_balance.each_with_object({}) do |(k, v), h|
        h[k] = BigDecimal(v[:balance].to_s) if v[:balance]
        h[k] ||= BigDecimal('0') if k.length == 2
      end
      if pre
        idx = (pre.keys + base.keys).uniq
        base = {}.tap do |h|
          idx.each { |k| h[k] = (base[k] || BigDecimal('0')) + (pre[k] || BigDecimal('0')) }
        end
      end
      self.class.total_subaccount(base)
    end

    def self.sum_matched(report, reg)
      report.select { |k, v| reg.match(k)}.values.sum
    end

    # for assert purpose
    #
    def self.gross(start_year, start_month, end_year = nil, end_month = nil,  code:  nil, date_range: nil, rows: 4)
      if ! date_range.nil?
        raise if date_range.class != Range
        # TODO: date based range search
      end

      end_year ||= start_year
      end_month ||= start_month
      sum = { debit: {}, credit: {}, debit_count: {}, credit_count: {} }
      idx_memo = []
      term(start_year, start_month, end_year, end_month, code) do |f, _path|
        CSV.new(f, headers: false, col_sep: "\t", encoding: 'UTF-8')
          .each_with_index do |row, i|
          break if i >= rows

          case i
          when 0
            idx_memo = row.map(&:to_s)
            next if code && !idx_memo.include?(code)

            idx_memo.each do |r|
              sum[:debit][r] ||= BigDecimal('0')
              sum[:debit_count][r] ||= 0
            end
          when 1
            next if code && !idx_memo.include?(code)

            row.each_with_index do |r, j|
              sum[:debit][idx_memo[j]] += BigDecimal(r.to_s)
              sum[:debit_count][idx_memo[j]] += 1
            end
          when 2
            idx_memo = row.map(&:to_s)
            break if code && !idx_memo.include?(code)

            idx_memo.each do |r|
              sum[:credit][r] ||= BigDecimal('0')
              sum[:credit_count][r] ||= 0
            end
          when 3
            row.each_with_index do |r, j|
              sum[:credit][idx_memo[j]] += BigDecimal(r.to_s)
              sum[:credit_count][idx_memo[j]] += 1
            end
          else
            puts row # for debug
          end
        end
      end
      if code
        sum[:debit] = sum[:debit][code] || BigDecimal('0')
        sum[:credit] = sum[:credit][code] || BigDecimal('0')
        sum[:debit_count] = sum[:debit_count][code] || 0
        sum[:credit_count] = sum[:credit_count][code] || 0
      end
      sum
    end

    # netting vouchers in specified term
    #
    def self.net(start_year, start_month, end_year = nil, end_month = nil, code: nil, date_range: nil)
      g = gross(start_year, start_month, end_year, end_month, code: code, date_range: date_range)
      idx = (g[:debit].keys + g[:credit].keys).uniq.sort
      count = {}
      diff = {}.tap do |sum|
        idx.each do |code|
          sum[code] = g.dig(:debit, code).nil? ? BigDecimal('0') : Util.calc_diff(g[:debit][code], code)
          sum[code] -= g.dig(:credit, code).nil? ? BigDecimal('0') : Util.calc_diff(g[:credit][code], code)
          count[code] = (g.dig(:debit_count, code) || 0) + (g.dig(:credit_count, code) || 0)
        end
      end
      [diff, count]
    end

    def render_xbrl(filename = nil)
      set_bs(2, legal: true)
      set_pl(3)
      country_suffix = CONFIG['country'] || 'en'
      @company = CGI.escapeHTML(CONFIG.dig('company', 'name'))
      @balance_sheet_selected = 'true'
      @pl_selected = 'true'
      @capital_change_selected = 'true'
      @issue_date = Date.today
      @xbrl_entries = @bs.map{ |k, v| xbrl_line(k, v) }.compact.join("\n")
      @xbrl_entries += @pl.map{ |k, v| xbrl_line(k, v) }.compact.join("\n")
      @filename = filename || @issue_date.to_s

      File.open("#{@filename}.xbrl", 'w') { |f| f.write render_erb(search_template("base-#{country_suffix}.xbrl.erb")) }
      File.open("#{@filename}.xsd", 'w') { |f| f.write render_erb(search_template("base-#{country_suffix}.xsd.erb")) }
    end

    def xbrl_line(code, amount)
      return nil if /^_/.match(code)

      context = /^[0-9]/.match(code) ? 'CurrentYearNonConsolidatedInstant' : 'CurrentYearNonConsolidatedDuration'
      tag = @dict.dig(code, :xbrl_id)
      #raise "xrrl_id not found: #{code}" if tag.nil?
      return nil if tag.nil?

      "<#{tag} decimals=\"0\" unitRef=\"JPY\" contextRef=\"#{context}\">#{readable(amount)}</#{tag}>"
    end

    private

    def set_bs(level = 3, legal: false)
      @start_balance.keys.each { |k| @data.first[k] ||= 0 }
      list = @data.map { |data| data.select { |k, _v| k.length <= level } }
      list.map! { |data| code_sum(data).merge(data) } if legal
      @bs = list.each_with_object({}) do |month, h|
        month.each do |k, v|
          next if /^_/.match(k)

          h[k] = (h[k] || BigDecimal('0')) + v
        end
      end
    end

    def set_pl(level = 2)
      keys = @data.inject([]) { |a, data| a + data.keys }
               .compact.select { |k| /^[A-H_].+/.match(k) }
               .uniq.sort
      keys.select! { |k| k.length <= level }
      @pl = @data.each_with_object({}) do |item, h|
        keys.each do |k|
          h[k] = (h[k] || BigDecimal('0')) + (item[k] || BigDecimal('0')) if /^[^_]/.match(k)
        end
        h['_d'] = 'Period Total'
      end
    end

    def legal_items
      return [] unless CONFIG['country']

      case CONFIG['country']
      when 'jp'
        ['31', '32', '33', '91', '911', '912', '913', '9131', '9132', '914', '9141', '9142', '915', '916', '92', '93']
      end
    end

    def lib_path
      __dir__
    end
  end
end
