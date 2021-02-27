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
      main_loop
    end

    def self.journals(window, *args)
      new(window, LucaBook::List.term(*args).list_journals)
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
      debit_length = Array(record["debit_code"]).length
      credit_length = Array(record["credit_code"]).length
      loop do
        window.setpos(0, 0)
        [debit_length, credit_length].max.times do |i|
          { 'id' => '' }.tap do |dat|
            if i < debit_length
              dat['debit_code'] = Array(record["debit_code"])[i]
              dat['debit_amount'] = Array(record["debit_amount"])[i]
            end
            if i < credit_length
              dat['credit_code'] = Array(record["credit_code"])[i]
              dat['credit_amount'] = Array(record["credit_amount"])[i]
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
      debit_code = dat['debit_code'].is_a?(Array) ? dat['debit_code'][0] : dat['debit_code']
      debit_amount = dat['debit_amount'].is_a?(Array) ? dat['debit_amount'][0] : dat['debit_amount']
      credit_code = dat['credit_code'].is_a?(Array) ? dat['credit_code'][0] : dat['credit_code']
      credit_amount = dat['credit_amount'].is_a?(Array) ? dat['credit_amount'][0] : dat['credit_amount']
      lines = [Array(dat['debit_code']).length, Array(dat['credit_code']).length].max
      sprintf("%s |%s| %s %s | %s %s",
              dat['id'],
              lines > 1 ? lines.to_s : ' ',
              (debit_code||'').mb_ljust(24, ' '),
              (debit_amount||'').to_s.mb_rjust(10, ' '),
              (credit_code||'').mb_ljust(24, ' '),
              (credit_amount||'').to_s.mb_rjust(10, ' ')
             )
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
