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
          if i == @active
            window.attron(A_REVERSE) { window << draw_line(dat) }
          else
            window << draw_line(dat)
          end
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
            window << draw_line(dat)
          end
          clrtoeol
          window << "\n"
        end
        (window.maxy - window.cury).times { window.deleteln() }
        window.refresh

        cmd = window.getch.to_s
        case cmd
        when 'q', KEY_CTRL_J
          break
        end
      end
    end

    private

    def draw_line(dat)
      date, txid = LucaSupport::Code.decode_id(dat[:id]) if dat[:id]
      debit_code = Array(dat[:debit]).dig(0, :code)
      debit_amount = Array(dat[:debit]).dig(0, :amount) || ''
      credit_code = Array(dat[:credit]).dig(0, :code)
      credit_amount = Array(dat[:credit]).dig(0, :amount) || ''
      lines = [Array(dat[:debit]).length, Array(dat[:credit]).length].max
      sprintf("%s %s |%s| %s %s | %s %s",
              date&.mb_rjust(10, ' ') || '',
              txid || '',
              lines > 1 ? lines.to_s : ' ',
              fmt_code(debit_code),
              debit_amount.to_s.mb_rjust(10, ' '),
              fmt_code(credit_code),
              credit_amount.to_s.mb_rjust(10, ' ')
             )
    end

    def fmt_code(code)
      width = (window.maxx / 3) < 30 ? 12 : 17
      return ''.mb_ljust(width, ' ') if code.nil?

      label = @dict.dig(code, :label)&.mb_truncate(12, omission: '')
      if width == 12
        label&.mb_ljust(width, ' ') || ''
      else
        sprintf("%s %s",
                code&.mb_ljust(4, ' ') || '',
                label&.mb_ljust(12, ' ') || '')
      end
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
