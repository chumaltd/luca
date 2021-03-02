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
      @visible = set_visible
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
          draw_line(dat, cursor)
          clrtoeol
          window << "\n"
        end
        window.refresh

        window.keypad(true)
        cmd = window.getch
        case cmd
        when KEY_DOWN, 'j', KEY_CTRL_N
          next if @index >= @data.length - 1

          @index += 1
          @active = @active >= window.maxy - 1 ? window.maxy - 1 : @active + 1
          @visible = set_visible
        when KEY_UP, 'k', KEY_CTRL_P
          next if @index <= 0

          @index -= 1
          @active = @active <= 0 ? 0 : @active - 1
          @visible = set_visible
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
        when 'q', KEY_CTRL_J
          break
        end
      end
    end

    private

    def draw_line(dat, cursor = nil)
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
        rest = sprintf("%s %s | %s %s", debit_cd, debit_amount, credit_cd, credit_amount)
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

    def set_visible
      return @data if @data.nil? || @data.length <= window.maxy

      if @visible.nil?
        @data.slice(0, window.maxy)
      else
        if @active == (window.maxy - 1)
          @data.slice(@index - window.maxy + 1, window.maxy)
        elsif @active == 0
          @data.slice(@index, window.maxy)
        else
          @visible
        end
      end
    end
  end
end
