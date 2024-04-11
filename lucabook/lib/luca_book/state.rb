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
    include Accumulator

    @dirname = 'journals'
    @@dict = LucaRecord::Dict.new('base.tsv')

    attr_reader :statement, :pl_data, :bs_data, :start_balance

    def initialize(data, count = nil, start_d: nil, end_d: nil)
      @monthly = data
      @count = count
      @start_date = start_d
      @end_date = end_d
      set_balance
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

    def self.by_code(code, from_year, from_month, to_year = from_year, to_month = from_month, recursive: false)
      code = search_code(code) if code
      date = Date.new(from_year.to_i, from_month.to_i, -1)
      last_date = Date.new(to_year.to_i, to_month.to_i, -1)
      raise 'invalid term specified' if date > last_date

      balance = start_balance(date.year, date.month, recursive: recursive)[code] || 0
      first_line = { 'code' => nil, 'label' => nil, 'debit_amount' => nil, 'debit_count' => nil, 'credit_amount' => nil, 'credit_count' => nil, 'net' => nil, 'balance' => balance, '_d' => nil }
      reports = [first_line].tap do |r|
        while date <= last_date do
          diff = {}.tap do |h|
            g = gross(date.year, date.month, code: code, recursive: recursive)
            sum = g.dig(:debit, code).nil? ? BigDecimal('0') : Util.calc_diff(g[:debit][code], code)
            sum -= g.dig(:credit, code).nil? ? BigDecimal('0') : Util.calc_diff(g[:credit][code], code)
            balance += sum
            h['code'] = code
            h['label'] = @@dict.dig(code, :label)
            h['debit_amount'] = g.dig(:debit, code)
            h['debit_count'] = g.dig(:debit_count, code)
            h['credit_amount'] = g.dig(:credit, code)
            h['credit_count'] = g.dig(:credit_count, code)
            h['net'] = sum
            h['balance'] = balance
            h['_d'] = date.to_s
          end
          r << diff
          date = Date.new(date.next_month.year, date.next_month.month, -1)
        end
      end
      LucaSupport::Code.readable(reports)
    end

    def code2label
      @statement ||= @monthly
      @statement.map do |report|
        {}.tap do |h|
          report.each { |k, v| h[@@dict.dig(k, :label) || k] = v }
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
      @count.prepend({}.tap { |header| keys.each { |k| header[k] = @@dict.dig(k, :label) }})
      @count
    end

    # TODO: pl/bs may not be immutable
    def report_mail(level = 3)
      @company = LucaSupport::CONST.config.dig('company', 'name')
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
      mail.to = LucaSupport::CONST.config.dig('mail', 'preview') || LucaSupport.CONST.config.dig('mail', 'from')
      mail.subject = 'Financial Report available'
      mail.html_part = Mail::Part.new(body: render_erb(search_template('monthly-report.html.erb')), content_type: 'text/html; charset=UTF-8')
      LucaSupport::Mail.new(mail, LucaSupport.CONST.pjdir).deliver
    end

    def bs(level = 3, legal: false)
      set_bs(level, legal: legal)
      base = accumulate_balance(@bs_data)
      rows = [base[:debit].length, base[:credit].length].max
      @statement = [].tap do |a|
        rows.times do |i|
          {}.tap do |res|
            res['debit_label'] = base[:debit][i] ? @@dict.dig(base[:debit][i].keys[0], :label) : ''
            #res['debit_balance'] = base[:debit][i] ? (@start_balance.dig(base[:debit][i].keys[0]) || 0) + base[:debit][i].values[0] : ''
            res['debit_balance'] = base[:debit][i] ? base[:debit][i].values[0] : ''
            res['credit_label'] = base[:credit][i] ? @@dict.dig(base[:credit][i].keys[0], :label) : ''
            #res['credit_balance'] = base[:credit][i] ? (@start_balance.dig(base[:credit][i].keys[0]) || 0) + base[:credit][i].values[0] : ''
            res['credit_balance'] = base[:credit][i] ? base[:credit][i].values[0] : ''
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
      @statement = @monthly.map do |data|
        {}.tap do |h|
          @pl_data.keys.each { |k| h[k] = data[k] || BigDecimal('0') }
        end
      end
      @statement << @pl_data
      readable(code2label)
    end

    # 
    def net_income
      set_pl(2)
      @pl_data['HA']
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

    def code_sum(report)
      legal_items.each.with_object({}) do |k, h|
        h[k] = self.class.sum_matched(report, /^#{k}.*/)
      end
    end

    def set_balance
      @start_balance = self.class.start_balance(@start_date.year, @start_date.month)
    end

    def self.start_balance(year, month, recursive: true)
      start_date = Date.new(year, month, 1)
      balance = Dict.latest_balance(start_date)
      base = balance.each_with_object({}) do |(k, v), h|
        h[k] = BigDecimal(v[:balance].to_s) if v[:balance]
        h[k] ||= BigDecimal('0') if k.length == 2
      end
      pre_first = Date.parse(balance.dig("_date", :label)).next_month
      if start_date <= pre_first
        return recursive ? total_subaccount(base) : base
      end

      pre_last = start_date.prev_month
      pre = accumulate_term(pre_first.year, pre_first.month, pre_last.year, pre_last.month)
      total = {}.tap do |h|
        (pre.keys + base.keys).uniq.each do |k|
          h[k] = (base[k] || BigDecimal('0')) + (pre[k] || BigDecimal('0'))
        end
      end
      recursive ? total_subaccount(total) : total
    end

    def write_xbrl(filename = nil)
      xbrl, xsd = render_xbrl(filename)
      doctype = %Q(<?xml version="1.0" encoding="UTF-8"?>)

      File.open("#{@filename}.xbrl", 'w') { |f| f.write [doctype, xbrl].join("\n") }
      File.open("#{@filename}.xsd", 'w') { |f| f.write [doctype, xsd].join("\n") }
    end

    def render_xbrl(filename = nil)
      set_bs(3, legal: true)
      set_pl(3)
      country_suffix = LucaSupport::CONST.config['country'] || 'en'
      @company = CGI.escapeHTML(LucaSupport::CONST.config.dig('company', 'name'))
      @balance_sheet_selected = 'true'
      @pl_selected = 'true'
      @capital_change_selected = 'true'
      @issue_date = Date.today

      prior_bs = @start_balance.filter { |k, _v| /^[9]/.match(k) }
      @xbrl_entries = @bs_data.map{ |k, v| xbrl_line(k, v, prior_bs[k]) }.compact.join("\n")
      @xbrl_entries += @pl_data.map{ |k, v| xbrl_line(k, v) }.compact.join("\n")
      @xbrl_entries += equity_change.join("\n")
      @filename = filename || "statement-#{@issue_date}"

      [render_erb(search_template("base-#{country_suffix}.xbrl.erb")), render_erb(search_template("base-#{country_suffix}.xsd.erb"))]
    end

    # TODO: proper decimals attr for each currency
    def xbrl_line(code, amount, prior_amount = nil)
      return nil if /^_/.match(code)

      context = /^[0-9]/.match(code) ? 'CurrentYearNonConsolidatedInstant' : 'CurrentYearNonConsolidatedDuration'
      tag = @@dict.dig(code, :xbrl_id)
      #raise "xbrl_id not found: #{code}" if tag.nil?
      return nil if tag.nil?
      return nil if readable(amount).zero? && prior_amount.nil?

      prior = if prior_amount.nil?
                /^[9]/.match(code) ? "<#{tag} decimals=\"0\" unitRef=\"#{Code.currency_code(LucaSupport::CONST.config['country'])}\" contextRef=\"Prior1YearNonConsolidatedInstant\">0</#{tag}>\n" : ''
              else
                "<#{tag} decimals=\"0\" unitRef=\"#{Code.currency_code(LucaSupport::CONST.config['country'])}\" contextRef=\"Prior1YearNonConsolidatedInstant\">#{readable(prior_amount)}</#{tag}>\n"
              end
      current = "<#{tag} decimals=\"0\" unitRef=\"#{Code.currency_code(LucaSupport::CONST.config['country'])}\" contextRef=\"#{context}\">#{readable(amount)}</#{tag}>"

      prior + current
    end

    def self.search_code(code)
      return code if @@dict.dig(code)

      @@dict.search(code).tap do |new_code|
        if new_code.nil?
          puts "Search word is not matched with labels"
          exit 1
        end
      end
    end

    private

    def set_bs(level = 3, legal: false)
      unless @monthly.first['_setup']
        @start_balance.each do |k, v|
          next if /^_/.match(k)
          @monthly.first[k] = (v || 0) + (@monthly.first[k] || 0)
        end
        @monthly.first['_setup'] = 'done'
      end
      list = @monthly.map { |data| data.select { |k, _v| k.length <= level } }
      list.map! { |data| code_sum(data).merge(data) } if legal
      @bs_data = list.each_with_object({}) do |month, h|
        month.each do |k, v|
          next if /^_/.match(k)

          h[k] = (h[k] || BigDecimal('0')) + v
        end
      end
    end

    def set_pl(level = 2)
      keys = @monthly.inject([]) { |a, data| a + data.keys }
               .compact.select { |k| /^[A-H_].+/.match(k) }
               .uniq.sort
      keys.select! { |k| k.length <= level }
      @pl_data = @monthly.each_with_object({}) do |item, h|
        keys.each do |k|
          h[k] = (h[k] || BigDecimal('0')) + (item[k] || BigDecimal('0')) if /^[^_]/.match(k)
        end
        h['_d'] = 'Period Total'
      end
    end

    def legal_items
      return [] unless LucaSupport::CONST.config['country']

      case LucaSupport::CONST.config['country']
      when 'jp'
        ['31', '32', '33', '91', '911', '912', '913', '9131', '9132', '914', '9141', '9142', '915', '916', '92', '93']
      end
    end

    def equity_change
      begin
        ex_dict = LucaRecord::Dict.new('ext.tsv')
      rescue
        return nil
      end

      changes = []
      LucaBook::Journal.filter_by_code(@start_date.year, @start_date.month, @end_date.year, @end_date.month, '9').each do |dat|
        debit_str = 'ASET' if dat[:debit].find { |e| /^[124]/.match(e[:code]) }
        debit_str ||= '33' if dat[:debit].find { |e| /^33/.match(e[:code]) }
        debit_str ||= 'ASET' if dat[:debit].find { |e| /^[3]/.match(e[:code]) }
        credit_str = 'DEBT' if dat[:credit].find { |e| /^[57]/.match(e[:code]) }
        credit_str ||= 'ASET' if dat[:credit].find { |e| /^[12]/.match(e[:code]) }
        dat[:credit].each do |entry|
          case entry[:code]
          when /^(91[0-9a-zA-Z]+)/
            code = $1
            debit_str ||= dat[:debit].find { |e| /^[9]/.match(e[:code]) }.dig(:code)
            debit_str = '914' if /^914[0-9a-zA-Z]+/.match(debit_str)
            tag = ex_dict.dig("#{debit_str}:c#{code}#{credit_str}")&.dig(:xbrl_id)
            changes << [tag, readable(entry[:amount])] if tag
          end
        end
        dat[:debit].each do |entry|
          case entry[:code]
          when /^(916[0-9a-zA-Z]*)/
            tag = ex_dict.dig("d#{$1}:_")&.dig(:xbrl_id)
            changes << [tag, readable(entry[:amount] * -1)] if tag
          when /^(91[0-57-9a-zA-Z]+)/
            code = $1
            credit_str ||= dat[:credit].find { |e| /^[9]/.match(e[:code]) }.dig(:code)
            credit_str = '914' if /^914[0-9a-zA-Z]+/.match(credit_str)
            tag = ex_dict.dig("#{debit_str}:c#{code}#{credit_str}")&.dig(:xbrl_id)
            changes << [tag, readable(entry[:amount])] if tag
          end
        end
      end
      set_bs(4) # require level 4 accounts
      @bs_data.each do |code, amount|
        next if /^[^9]/.match(code)

        diff = amount - (@start_balance[code]||0)
        next if diff == 0

        tag = ex_dict.dig("#{code}:#{code}")&.dig(:xbrl_id)
        changes << [tag, readable(diff)] if tag
      end
      currency = %Q(unitRef="#{Code.currency_code(LucaSupport::CONST.config['country'])}")
      context = 'contextRef="CurrentYearNonConsolidatedDuration"'
      changes.map { |tag, amount| %Q(<#{tag} decimals="0" #{currency} #{context}>#{amount}</#{tag}>) }
    end

    def lib_path
      __dir__
    end
  end
end
