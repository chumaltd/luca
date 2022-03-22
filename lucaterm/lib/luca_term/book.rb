# frozen_string_literal: true

require 'curses'
require "unicode/display_width/string_ext"
require 'mb_string'
require 'luca_book'
require 'json'
module LucaTerm
  class Book
    include Curses
    attr_accessor :window, :modeline

    def initialize(window, year, month, data=nil)
      @modeline = Window.new(1, 0, 0, 0)
      @window = window
      @year = year
      @month = month
      @data = data
      @index = 0
      @active = 0  # active line in window
      @visible = set_visible(@data)
      @dict = LucaRecord::Dict.load('base.tsv')
      main_loop
    end

    def self.journals(window, *args)
      new(window, args[0], args[1], LucaSupport::Code.readable(LucaBook::List.term(*args).data))
    end

    # render monthly journal list
    #
    def main_loop
      loop do
        modeline.setpos(0, 0)
        modeline << "#{Date::ABBR_MONTHNAMES[@month.to_i]} #{@year}"
        modeline.clrtoeol
        modeline.refresh

        window.setpos(0,0)
        @visible.each.with_index(0) do |dat, i|
          cursor = i == @active ? :full : nil
          draw_line(dat, cursor, true)
          window << "\n"
        end
        (window.maxy - window.cury).times { window << "\n" }
        window.refresh

        window.keypad(true)
        cmd = window.getch
        case cmd
        when KEY_DOWN, 'j', KEY_CTRL_N
          next if @index >= @data.length - 1

          cursor_down @data
        when KEY_UP, 'k', KEY_CTRL_P
          next if @index <= 0

          cursor_up @data
        when 'G'
          cursor_last @data
        when 'm'
          ym = edit_dialog('Enter: [yyyy] m', title: 'Change Month')&.split(/[\/\s]/)
          ym = [@year, ym[0]] if ym.length == 1
          @data = LucaSupport::Code.readable(LucaBook::List.term(*ym).data)
          @year, @month = ym
          @index = 0
          @active = 0
          @visible = set_visible(@data)
        when '<'
          target = Date.parse("#{@year}-#{@month}-1").prev_month
          @data = LucaSupport::Code.readable(LucaBook::List.term(target.year, target.month).data)
          @year, @month = target.year, target.month
          @index = 0
          @active = 0
          @visible = set_visible(@data)
        when '>'
          target = Date.parse("#{@year}-#{@month}-1").next_month
          @data = LucaSupport::Code.readable(LucaBook::List.term(target.year, target.month).data)
          @year, @month = target.year, target.month
          @index = 0
          @active = 0
          @visible = set_visible(@data)
        when KEY_ENTER, KEY_CTRL_J
          show_detail(@data[@index])
          @visible = set_visible(@data)
        when 'N'
          newdate = edit_dialog "Enter date of new record: YYYY-m-d", title: 'Create Journal'
          tmpl = {
            date: newdate,
            debit: [
              { code: '10XX', amount: 0 }
            ],
            credit: [
              { code: '50XX', amount: 0 }
            ],
          }
          show_detail(tmpl)
        when 'q'
          exit 0
        end
      end
    end

    # render each journal
    #
    def show_detail(record)
      @d_v = 0
      @d_h = 0
      debit_length = Array(record[:debit]).length
      credit_length = Array(record[:credit]).length
      date, txid = LucaSupport::Code.decode_id(record[:id]) if record[:id]
      fileid = record[:id].split('/').last if record[:id]
      date ||= record[:date]
      modeline.setpos(0, 0)
      modeline << "#{date} #{fileid} "
      modeline.clrtoeol
      modeline.refresh

      loop do
        window.setpos(0, 0)
        if record.dig(:headers, 'x-customer')
          window << format(" [%s] ", record.dig(:headers, 'x-customer'))
        end
        window << record[:note]
        clrtoeol; window << "\n"
        [debit_length, credit_length].max.times do |i|
          { id: nil, debit: [], credit: [] }.tap do |dat|
            if i < debit_length
              dat[:debit] << Array(record[:debit])[i]
            end
            if i < credit_length
              dat[:credit] << Array(record[:credit])[i]
            end
            cursor = @d_v == i ? @d_h : nil
            draw_line(dat, cursor)
          end
          clrtoeol
          window << "\n"
        end
        (window.maxy - window.cury).times { window << "\n" }
        window.refresh

        window.keypad(true)
        cmd = window.getch
        case cmd
        when KEY_DOWN, 'j', KEY_CTRL_N
          case @d_h
          when 0, 1
            @d_v = @d_v >= debit_length - 1 ? 0 : @d_v + 1
          else  #2,3
            @d_v = @d_v >= credit_length - 1 ? 0 : @d_v + 1
          end
        when KEY_UP, 'k', KEY_CTRL_P
          case @d_h
          when 0, 1
            @d_v = @d_v == 0 ? debit_length - 1 : @d_v - 1
          else  #2,3
            @d_v = @d_v == 0 ? credit_length - 1 : @d_v - 1
          end
        when KEY_LEFT, 'h', KEY_CTRL_B
          case @d_h
          when 1, 3
            @d_h -= 1
          when 2
            @d_v = debit_length - 1 if @d_v > debit_length - 1
            @d_h -= 1
          else # 0
            @d_v = credit_length - 1 if @d_v > credit_length - 1
            @d_h = 3
          end
        when KEY_RIGHT, 'l', KEY_CTRL_F
          case @d_h
          when 0, 2
            @d_h += 1
          when 1
            @d_v = credit_length - 1 if @d_v > credit_length - 1
            @d_h += 1
          else # 3
            @d_v = debit_length - 1 if @d_v > debit_length - 1
            @d_h = 0
          end
        when 'n'
          position = [0, 1].include?(@d_h) ? :debit : :credit
          new_code = select_code
          next if new_code.nil?

          new_amount = edit_amount
          next if new_amount.nil?

          record[position] << { code: new_code, amount: new_amount }
          debit_length = Array(record[:debit]).length
          credit_length = Array(record[:credit]).length
        when KEY_CTRL_J
          position, counter = [0,1].include?(@d_h) ? [:debit, :credit] : [:credit, :debit]
          if [0, 2].include? @d_h
            new_code = select_code
            next if new_code.nil?

            record[position][@d_v][:code] = new_code
          else
            diff = record[counter].map { |c| c[:amount] }.sum - record[position].map { |p| p[:amount] }.sum + record[position][@d_v][:amount]
            new_amount = edit_amount(record[position][@d_v][:amount], diff)
            next if new_amount.nil?

            record[position][@d_v][:amount] = new_amount
          end
        when 's', KEY_CTRL_S
          if record[:id]
            LucaBook::Journal.save record
          else
            LucaBook::Journal.create record
          end
          break
        when 'q'
          break
        end
      end
    end

    # returns amount after edit
    #
    def edit_amount(current = nil, diff = nil)
      diff_msg = diff.nil? ? '' : "#{diff} meets balance."
      begin
        scmd = edit_dialog "Current: #{current&.to_s}", diff_msg, title: 'Edit Amount'
        return nil if scmd.length == 0
        # TODO: guard from not number
        return scmd.to_i
      rescue
        return nil
      end
    end

    def edit_dialog(message = '', submessage = '', title: '')
      sub = window.subwin(5, 30, (window.maxy-5)/2, (window.maxx - 30)/2)
      sub.setpos(1, 1)
      sub << "  #{message}"
      sub.clrtoeol
      sub.setpos(2, 1)
      sub.clrtoeol
      sub.setpos(2, 3)
      sub.attron(A_REVERSE) { sub << "  > #{' ' * (30 - 9)}" }
      sub.setpos(3, 1)
      sub << "  #{submessage}"
      sub.clrtoeol
      sub.box(?|, ?-)
      sub.setpos(0, 2)
      sub << "[ #{title} ]"
      sub.setpos(2, 7)
      sub.refresh
      loop do
        echo
        scmd = sub.getstr
        noecho
        sub.close
        return scmd
      end
    end

    # returns Account code after selection from list dialog
    #
    def select_code
      top = window.maxy >= 25 ? 5 : 2
      sub = window.subwin(window.maxy - top, window.maxx - 4, top, 2)
      padding = ' ' * account_index(sub.maxx)[0].length
      list = @dict.reject{ |code, _e| code.length < 3 || /^[15]0XX/.match(code) || /^[89]ZZ/.match(code) }
               .map{ |code, entry| { code: code, label: entry[:label], category: padding } }
      tabstop = ['1', '5', '9', 'A', 'C'].map { |cap| list.index { |ac| /^#{cap}/.match(ac[:code]) } }.compact
      account_index(sub.maxx).each.with_index do |cat, i|
        list[tabstop[i]][:category] = cat
      end
      visible_dup = @visible
      index_dup = @index
      active_dup = @active
      @index = 0
      @active = 0
      @visible = nil
      @visible = set_visible(list, sub.maxy - 2)
      loop do
        @visible.each.with_index(0) do |entry, i|
          sub.setpos(i+1, 1)
          head = entry[:code].length == 3 ? '' : '  '
          line = format("%s %s %s %s", head, entry[:category], entry[:code], entry[:label])
          if i == @active
            sub.attron(A_REVERSE) { sub << line }
          else
            sub << line
          end
          sub.clrtoeol
          #sub << "\n"
        end
        (window.maxy - window.cury).times { window << "\n" }
        sub.box(?|, ?-)
        sub.setpos(0, 2)
        sub << "[ Select Account ]"
        sub.refresh

        cmd = window.getch
        case cmd
        when KEY_DOWN, 'j', KEY_CTRL_N
          next if @index >= list.length - 1

          cursor_down list, sub.maxy - 2
        when KEY_NPAGE
          cursor_pagedown list, sub.maxy - 2
        when KEY_UP, 'k', KEY_CTRL_P
          next if @index <= 0

          cursor_up list
        when KEY_PPAGE
          cursor_pageup list, sub.maxy - 2
        when KEY_LEFT
          cursor_jump tabstop, list, rev: true
        when KEY_RIGHT
          cursor_jump tabstop, list
        when 'G'
          cursor_last list, sub.maxy - 2
        when KEY_CTRL_J
          selected = list[@index][:code]
          @visible = visible_dup
          @index = index_dup
          @active = active_dup
          sub.close
          return selected
        when 'q'
          @visible = visible_dup
          @index = index_dup
          @active = active_dup
          sub.close
          return nil
        end
      end
    end

    private

    def account_index(maxx = 50)
      term = if maxx >= 45
               ['Assets', 'Liabilities', 'Net Assets', 'Sales', 'Expenses']
             elsif maxx >= 40
               ['Assets', 'LIAB', 'NetAsset', 'Sales', 'EXP']
             else
               ['', '', '', '', '']
             end
      len = term.map { |str| str.length }.max
      term.map { |str| str += ' ' * (len - str.length) }
    end

    def draw_line(dat, cursor = nil, note = false)
      date, txid = LucaSupport::Code.decode_id(dat[:id]) if dat[:id]
      date_str = date.nil? ? '' : date.split('-')[1, 2].join('/')&.mb_rjust(5, ' ')
      debit_cd = fmt_code(dat[:debit])
      debit_amount = fmt_amount(dat[:debit])
      credit_cd = fmt_code(dat[:credit])
      credit_amount = fmt_amount(dat[:credit])
      lines = [Array(dat[:debit]).length, Array(dat[:credit]).length].max
      lines = if lines == 1
                ' '
              elsif lines > 9
                '+'
              else
                lines
              end
      window << sprintf("%s |%s| ",
                        date_str,
                        lines,
                       )
      case cursor
      when 0
        window.attron(A_REVERSE) { window << debit_cd }
        window << sprintf(" %s | %s %s", debit_amount, credit_cd, credit_amount)
      when 1
        window << sprintf("%s ", debit_cd)
        window.attron(A_REVERSE) { window << debit_amount }
        window << sprintf(" | %s %s", credit_cd, credit_amount)
      when 2
        window << sprintf("%s %s | ", debit_cd, debit_amount)
        window.attron(A_REVERSE) { window << credit_cd }
        window << sprintf(" %s", credit_amount)
      when 3
        window << sprintf("%s %s | %s ", debit_cd, debit_amount, credit_cd)
        window.attron(A_REVERSE) { window << credit_amount }
      else
        rest = format("%s %s | %s %s", debit_cd, debit_amount, credit_cd, credit_amount)
        if note && window.maxx > 70
          rest += " | #{dat[:note]&.mb_truncate(window.maxx - 70)}"
        end
        if cursor == :full
          window.attron(A_REVERSE) { window << rest }
        else
          window << rest
        end
      end
    end

    def fmt_code(record)
      cd = Array(record).dig(0, :code)
      width = (window.maxx / 3) < 30 ? 12 : 17
      return ''.mb_ljust(width, ' ') if cd.nil?

      label = @dict.dig(cd, :label)&.mb_truncate(12, omission: '')
      if width == 12
        label&.mb_ljust(width, ' ') || ''
      else
        sprintf("%s %s",
                cd&.mb_ljust(4, ' ') || '',
                label&.mb_ljust(12, ' ') || '')
      end
    end

    def fmt_amount(record)
      amount = Array(record).dig(0, :amount) || ''
      amount.to_s.mb_rjust(10, ' ')
    end

    def cursor_up(data)
      @index -= 1
      @active = @active <= 0 ? 0 : @active - 1
      @visible = set_visible(data)
    end

    def cursor_pageup(data, maxy = nil)
      maxy ||= window.maxy
      n_idx = @index - maxy
      return if n_idx <= 0

      @index = n_idx
      @active = 0
      @visible = set_visible(data, maxy)
    end

    def cursor_down(data, maxy = nil)
      maxy ||= window.maxy
      @index += 1
      @active = @active >= maxy - 1 ? @active : @active + 1
      @visible = set_visible(data, maxy)
    end

    def cursor_pagedown(data, maxy = nil)
      maxy ||= window.maxy
      n_idx = @index + maxy
      return if n_idx >= data.length - 1

      @index = n_idx
      @active = 0
      @visible = set_visible(data, maxy)
    end

    def cursor_jump(tabstop, data, rev: false)
      @index = if rev
                 tabstop.filter{ |t| t < @index ? t : nil }.max || @index
               else
                 tabstop.filter{ |t| t > @index ? t : nil }.min || @index
               end

      @active = 0
      @visible = set_visible(data)
    end

    def cursor_last(data, maxy = nil)
      maxy ||= window.maxy
      @index = data.length - 1
      @active = maxy - 1
      @visible = set_visible(data, maxy)
    end

    def set_visible(data, maxy = nil)
      maxy ||= window.maxy
      return data if data.nil? || data.length <= maxy

      if @visible.nil?
        data.slice(0, maxy)
      else
        if @active == (maxy - 1)
          data.slice(@index - maxy + 1, maxy)
        elsif @active == 0
          data.slice(@index, maxy)
        else
          @visible
        end
      end
    end
  end
end
