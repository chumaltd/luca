# frozen_string_literal: true

require 'bigdecimal'
require 'luca_support/config'

module LucaBook
  module Util
    module_function

    # items assumed as bellows:
    #   [{ code: '113', amount: 1000 }, ... ]
    #
    def diff_by_code(items, code)
      calc_diff(amount_by_code(items, code), code)
    end

    def amount_by_code(items, code)
      items
        .select { |item| item.dig(:code) == code }
        .inject(BigDecimal('0')) { |sum, item| sum + item[:amount] }
    end

    def calc_diff(num, code)
      num * pn_debit(code.to_s)
    end

    def pn_debit(code)
      case code
      when /^[0-4BCEGH]/
        1
      when /^[5-9ADF]/
        -1
      else
        nil
      end
    end
  end
end
