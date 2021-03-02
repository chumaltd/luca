# frozen_string_literal: true

require 'curses'
require "unicode/display_width/string_ext"
require 'mb_string'
require 'luca_book'

module LucaTerm
  class Book
    include Curses
    attr_accessor :window

    def initialize(window, data=nil)
      @window = window
      @data = data
      @index = 0
      @active = 0  # active line in window
      @visible = set_visible(@data)
      @dict = LucaRecord::Dict.load('base.tsv')
      main_loop
    end

    def self.journals(window, *args)
      new(window, LucaSupport::Code.readable(LucaBook::List.term(*args).data))
    end

    def main_loop
      loop do
        window.setpos(0,0)
        @visible.each.with_index(0) do |dat, i|
          cursor = i == @active ? :full : nil
          draw_line(dat, cursor, true)
          clrtoeol
          window << "\n"
        end
        (window.maxy - window.cury).times { window.deleteln() }
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
          ym = edit_dialog('Change month: yyyy m')&.split(/[\/\s]/)
          @data = LucaSupport::Code.readable(LucaBook::List.term(*ym).data)
          @index = 0
          @active = 0
          @visible = set_visible(@data)
        when KEY_ENTER, KEY_CTRL_J
          show_detail(@data[@index])
        when 'q'
          exit 0
        end
      end
    end

    def show_detail(record)
      @d_v = 0
      @d_h = 0
      debit_length = Array(record[:debit]).length
      credit_length = Array(record[:credit]).length
      date, txid = LucaSupport::Code.decode_id(record[:id]) if record[:id]
      loop do
        window.setpos(0, 0)
        window << "#{date}  "
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
        (window.maxy - window.cury).times { window.deleteln() }
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
          position = [0,1].include?(@d_h) ? :debit : :credit
          new_code = select_code
          next if new_code.nil?

          new_amount = edit_amount
          next if new_amount.nil?

          record[position] << { code: new_code, amount: new_amount }
          debit_length = Array(record[:debit]).length
          credit_length = Array(record[:credit]).length
        when KEY_CTRL_J
          position = [0,1].include?(@d_h) ? :debit : :credit
          if [0, 2].include? @d_h
            new_code = select_code
            next if new_code.nil?

            record[position][@d_v][:code] = new_code
          else
            new_amount = edit_amount(record[position][@d_v][:amount])
            next if new_amount.nil?

            record[position][@d_v][:amount] = new_amount
          end
        when 's', KEY_CTRL_S
          LucaBook::Journal.save record
          break
        when 'q'
          break
        end
      end
    end

    def edit_amount(current = nil)
      begin
        scmd = edit_dialog "Current: #{current&.to_s}"
        return nil if scmd.length == 0
        # TODO: guard from not number
        return scmd.to_i
      rescue
        return nil
      end
    end

    def edit_dialog(message = '')
      sub = window.subwin(4, 30, (window.maxy-4)/2, (window.maxx - 30)/2)
      sub.box(?|, ?-)
      sub.setpos(1, 3)
      sub << message
      clrtoeol
      sub.setpos(2, 3)
      sub << "> "
      clrtoeol
      sub.refresh
      loop do
        echo
        scmd = sub.getstr
        noecho
        sub.close
        return scmd
      end
    end

    def select_code
      list = @dict.map{ |code, entry| { code: code, label: entry[:label] } }
      visible_dup = @visible
      index_dup = @index
      active_dup = @active
      @index = 0
      @active = 0
      @visible = nil
      @visible = set_visible(list)
      loop do
        window.setpos(0,0)
        @visible.each.with_index(0) do |entry, i|
          line = format("%s %s", entry[:code], entry[:label])
          if i == @active
            window.attron(A_REVERSE) { window << line }
          elsif @visible[i][:code].length <= 2
            window.attron(A_UNDERLINE) { window << line }
          else
            window << line
          end
          clrtoeol
          window << "\n"
        end
        (window.maxy - window.cury).times { window.deleteln() }
        window.refresh

        cmd = window.getch
        case cmd
        when KEY_DOWN, 'j', KEY_CTRL_N
          next if @index >= list.length - 1

          cursor_down list
        when KEY_NPAGE
          cursor_pagedown list
        when KEY_UP, 'k', KEY_CTRL_P
          next if @index <= 0

          cursor_up list
        when KEY_PPAGE
          cursor_pageup list
        when 'G'
          cursor_last list
        when KEY_CTRL_J
          code = list[@index][:code]
          @visible = visible_dup
          @index = index_dup
          @active = active_dup
          return code
        when 'q'
          @visible = visible_dup
          @index = index_dup
          @active = active_dup
          return nil
        end
      end
    end

    private

    def draw_line(dat, cursor = nil, note = false)
      date, txid = LucaSupport::Code.decode_id(dat[:id]) if dat[:id]
      debit_cd = fmt_code(dat[:debit])
      debit_amount = fmt_amount(dat[:debit])
      credit_cd = fmt_code(dat[:credit])
      credit_amount = fmt_amount(dat[:credit])
      lines = [Array(dat[:debit]).length, Array(dat[:credit]).length].max
      window << sprintf("%s %s |%s| ",
                        date&.mb_rjust(10, ' ') || '',
                        txid || '',
                        lines > 1 ? lines.to_s : ' ',
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
        if note && window.maxx > 80
          rest += " | #{dat[:note].mb_truncate(window.maxx - 80)}"
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

    def cursor_pageup(data)
      n_idx = @index - window.maxy
      return if n_idx <= 0

      @index = n_idx
      @active = 0
      @visible = set_visible(data)
    end

    def cursor_down(data)
      @index += 1
      @active = @active >= window.maxy - 1 ? window.maxy - 1 : @active + 1
      @visible = set_visible(data)
    end

    def cursor_pagedown(data)
      n_idx = @index + window.maxy
      return if n_idx >= data.length - 1

      @index = n_idx
      @active = 0
      @visible = set_visible(data)
    end

    def cursor_last(data)
      @index = data.length - 1
      @active = window.maxy - 1
      @visible = set_visible(data)
    end

    def set_visible(data)
      return data if data.nil? || data.length <= window.maxy

      if @visible.nil?
        data.slice(0, window.maxy)
      else
        if @active == (window.maxy - 1)
          data.slice(@index - window.maxy + 1, window.maxy)
        elsif @active == 0
          data.slice(@index, window.maxy)
        else
          @visible
        end
      end
    end
  end
end
