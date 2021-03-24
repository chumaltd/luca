# frozen_string_literal: true

require 'pathname'
require 'date'
require 'luca_support'
require 'luca_record'
require 'luca_record/dict'
require 'luca_book'

module LucaBook #:nodoc:
  # Journal List on specified term
  #
  class List < LucaBook::Journal
    @dirname = 'journals'
    @@dict = LucaRecord::Dict.new('base.tsv')
    attr_reader :data

    def initialize(data, start_date, code = nil)
      @data = data
      @code = code
      @start = start_date
    end

    def self.term(from_year, from_month, to_year = from_year, to_month = from_month, code: nil, basedir: @dirname, recursive: false)
      code = search_code(code) if code
      data = LucaBook::Journal.term(from_year, from_month, to_year, to_month, code).select do |dat|
        if code.nil?
          true
        else
          if recursive
            ! [:debit, :credit].map { |key| serialize_on_key(dat[key], :code) }.flatten.select { |idx|  /^#{code}/.match(idx) }.empty?
          else
            [:debit, :credit].map { |key| serialize_on_key(dat[key], :code) }.flatten.include?(code)
          end
        end
      end
      new data, Date.new(from_year.to_i, from_month.to_i, 1), code
    end

    def self.add_header(from_year, from_month, to_year = from_year, to_month = from_month, code: nil, header_key: nil, header_val: nil)
      return nil if code.nil?
      return nil unless Journal::ACCEPTED_HEADERS.include?(header_key)

      term(from_year, from_month, to_year, to_month, code: code)
        .data.each do |journal|
        Journal.add_header(journal, header_key, header_val)
      end
    end

    def list_by_code(recursive = false)
      calc_code(recursive: recursive)
      convert_label
      @data = [code_header] + @data.map do |dat|
        date, txid = LucaSupport::Code.decode_id(dat[:id])
        {}.tap do |res|
          res['code'] = dat[:code].length == 1 ? dat[:code].first : dat[:code]
          res['date'] = date
          res['no'] = txid
          res['id'] = dat[:id]
          res['diff'] = dat[:diff]
          res['balance'] = dat[:balance]
          res['counter_code'] = dat[:counter_code].length == 1 ? dat[:counter_code].first : dat[:counter_code]
          res['note'] = dat[:note]
        end
      end
      readable(@data)
    end

    def list_journals
      convert_label
      @data = @data.map do |dat|
        date, txid = LucaSupport::Code.decode_id(dat[:id])
        {}.tap do |res|
          res['date'] = date
          res['no'] = txid
          res['id'] = dat[:id]
          res['debit_code'] = dat[:debit].length == 1 ? dat[:debit][0][:code] : dat[:debit].map { |d| d[:code] }
          res['debit_amount'] = dat[:debit].inject(0) { |sum, d| sum + d[:amount] }
          res['credit_code'] = dat[:credit].length == 1 ? dat[:credit][0][:code] : dat[:credit].map { |d| d[:code] }
          res['credit_amount'] = dat[:credit].inject(0) { |sum, d| sum + d[:amount] }
          res['note'] = dat[:note]
        end
      end
      readable(@data)
    end

    def accumulate_code
      @data.inject(BigDecimal('0')) do |sum, dat|
        sum + Util.diff_by_code(dat[:debit], @code) - Util.diff_by_code(dat[:credit], @code)
      end
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

    def render_html(file_type = :html)
      start_balance = set_balance(true)
      @journals = group_by_code.map do |account|
        balance = start_balance[account[:code]] || BigDecimal('0')
        table = []
        table << %Q(<h2 class="title">#{@@dict.dig(account[:code], :label)}</h2>)

        account[:vouchers].map { |voucher| filter_by_code(voucher, account[:code]) }.flatten
          .unshift({ balance: readable(balance) })
          .map { |row|
          balance += Util.pn_debit(account[:code]) * ((row.dig(:amount, :debit) || 0) - (row.dig(:amount, :credit) || 0))
          row[:balance] = readable(balance)
          row
          }
          .map { |row| render_line(row) }
          .each_slice(28) do |rows|
          table << table_header
          table << rows.join("\n")
          table << table_footer
          table << %Q(<hr class='pgbr' />)
        end
        table[0..-2].join("\n")
      end

      case file_type
      when :html
        render_erb(search_template('journals.html.erb'))
      when :pdf
        erb2pdf(search_template('journals.html.erb'))
      else
        raise 'This filetype is not supported.'
      end
    end

    def table_header
      %Q(<table>
        <thead>
        <th>Date<br />No</th>
        <th>Counter account</th>
        <th>Sub account<br />Note</th>
        <th>Debit</th>
        <th>Credit</th>
        <th>Balance</th>
        </thead>
        <tbody>)
    end

    def table_footer
      %Q(</tbody>
        </table>)
    end

    def filter_by_code(voucher, code)
      [:debit, :credit].each_with_object([]) do |balance, lines|
        voucher[balance].each do |record|
          next unless /^#{code}/.match(record[:code])

          counter_balance = (balance == :debit) ? :credit : :debit
          view = { code: record[:code], amount: {} }
          view[:date], view[:txid] = decode_id(voucher[:id])
          view[:label] = @@dict.dig(record[:code], :label) if record[:code].length >= 4
          view[:amount][balance] = readable(record[:amount])
          view[:counter_code] = voucher.dig(counter_balance, 0, :code)
          view[:counter_label] = @@dict.dig(view[:counter_code], :label) || ''
          view[:counter_label] += ' sundry a/c' if voucher[counter_balance].length > 1
          view[:note] = voucher[:note]
          lines << view
        end
      end
    end

    def render_line(view)
          %Q(<tr>
          <td class="date">#{view[:date]}<br /><div>#{view[:txid]}</div></td>
          <td class="counter">#{view[:counter_label]}</td>
          <td class="note">#{view[:label]}<br /><div class="note">#{view[:note]}</div></td>
          <td class="debit amount">#{view.dig(:amount, :debit)}</td>
          <td class="credit amount">#{view.dig(:amount, :credit)}</td>
          <td class="balance">#{view[:balance]}</td>
          </tr>)
    end

    def group_by_code(level = 3)
      list_accounts.map do |code|
        vouchers = @data.filter do |voucher|
          codes = [:debit, :credit].map do |balance|
            voucher[balance].map { |record| record[:code][0, level] }
          end
          codes.flatten.include?(code)
        end
        { code: code, vouchers: vouchers }
      end
    end

    def list_accounts(level = 3)
      return nil if level < 3

      list = @data.each_with_object([]) do |voucher, codes|
        [:debit, :credit].each do |balance|
          voucher[balance].each do |record|
            next if record[:code].length < level

            codes << record[:code][0, level]
          end
        end
      end
      list.uniq.sort
    end

    private

    def set_balance(recursive = false)
      return LucaBook::State.start_balance(@start.year, @start.month, recursive: recursive) if @code.nil?
      return BigDecimal('0') if /^[A-H]/.match(@code)

      LucaBook::State.start_balance(@start.year, @start.month, recursive: recursive)[@code] || BigDecimal('0')
    end

    def calc_code(recursive: false)
      @balance = set_balance(recursive)
      if @code
        balance = @balance
        @data.each do |dat|
          dat[:diff] = Util.diff_by_code(dat[:debit], @code) - Util.diff_by_code(dat[:credit], @code)
          balance += dat[:diff]
          dat[:balance] = balance
          target, counter = dat[:diff] * Util.pn_debit(@code) > 0 ? [:debit, :credit] : [:credit, :debit]
          dat[:code] = dat[target].map { |d| d[:code] }
          dat[:counter_code] = dat[counter].map { |d| d[:code] }
        end
      end
      self
    end

    def convert_label
      @data.each do |dat|
        if @code
          dat[:code] = dat[:code].map { |target| "#{target} #{@@dict.dig(target, :label)}" }
          dat[:counter_code] = dat[:counter_code].map { |counter| "#{counter} #{@@dict.dig(counter, :label)}" }
        else
          dat[:debit].each { |debit| debit[:code] = "#{debit[:code]} #{@@dict.dig(debit[:code], :label)}" }
          dat[:credit].each { |credit| credit[:code] = "#{credit[:code]} #{@@dict.dig(credit[:code], :label)}" }
        end
      end
      self
    end

    def code_header
      {}.tap do |h|
        %w[code date no id diff balance counter_code note].each do |k|
          h[k] = k == 'balance' ? @balance : ''
        end
      end
    end

    def lib_path
      __dir__
    end
  end
end
