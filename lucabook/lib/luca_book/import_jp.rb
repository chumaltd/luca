# frozen_string_literal: true

require 'date'
require 'luca_book'
require 'luca_support'

module LucaBook
  class Import
    # TODO: need to be separated into pluggable l10n module.
    # TODO: gensen rate >1m yen.
    # TODO: gensen & consumption `round()` rules need to be confirmed.
    # Profit or Loss account should be specified as code1.
    #
    def tax_extension(code1, code2, amount, options)
      return nil if options.nil? || options[:tax_options].nil?
      return nil if !options[:tax_options].include?('jp-gensen') && !options[:tax_options].include?('jp-consumption')

      gensen_rate = BigDecimal('0.1021')
      consumption_rate = BigDecimal('0.1')
      gensen_code = @code_map.dig(options[:gensen_label]) || @code_map.dig('預り金')
      gensen_idx = /^[5-8B-G]/.match(code1) ? 1 : 0
      consumption_idx = /^[A-G]/.match(code1) ? 0 : 1
      consumption_code = @code_map.dig(options[:consumption_label])
      consumption_code ||= /^[A]/.match(code1) ? @code_map.dig('仮受消費税等') : @code_map.dig('仮払消費税等')
      if options[:tax_options].include?('jp-gensen') && options[:tax_options].include?('jp-consumption')
        paid_rate = BigDecimal('1') + consumption_rate - gensen_rate
        gensen_amount = (amount / paid_rate * gensen_rate).round
        consumption_amount = (amount / paid_rate * consumption_rate).round
        [].tap do |res|
          res << [].tap do |res1|
            amount1 = amount
            amount1 -= consumption_amount if consumption_idx == 0
            amount1 += gensen_amount if gensen_idx == 1
            res1 << { 'code' => code1, 'amount' => amount1 }
            res1 << { 'code' => consumption_code, 'amount' => consumption_amount } if consumption_idx == 0
            res1 << { 'code' => gensen_code, 'amount' => gensen_amount } if gensen_idx == 0
          end
          res << [].tap do |res2|
            amount2 = amount
            amount2 -= consumption_amount if consumption_idx == 1
            amount2 += gensen_amount if gensen_idx == 0
            res2 << { 'code' => code2, 'amount' => amount2 }
            res2 << { 'code' => consumption_code, 'amount' => consumption_amount } if consumption_idx == 1
            res2 << { 'code' => gensen_code, 'amount' => gensen_amount } if gensen_idx == 1
          end
        end
      elsif options[:tax_options].include?('jp-gensen')
        paid_rate = BigDecimal('1') - gensen_rate
        gensen_amount = (amount / paid_rate * gensen_rate).round
        [].tap do |res|
          res << [].tap do |res1|
            amount1 = amount
            amount1 += gensen_amount if gensen_idx == 1
            res1 << { 'code' => code, 'amount' => amount1 }
            res1 << { 'code' => gensen_code, 'amount' => gensen_amount } if gensen_idx == 0
          end
          res << [].tap do |res2|
            amount2 = amount
            amount2 += gensen_amount if gensen_idx == 0
            mount2 ||= amount
            res2 << { 'code' => code2, 'amount' => amount2 }
            res2 << { 'code' => gensen_code, 'amount' => gensen_amount } if gensen_idx == 1
          end
        end
      elsif options[:tax_options].include?('jp-consumption')
        paid_rate = BigDecimal('1') + consumption_rate - gensen_rate
        consumption_amount = (amount / paid_rate * consumption_rate).round
        res << [].tap do |res1|
          amount1 = amount
          amount1 -= consumption_amount if consumption_idx == 0
          res1 << { 'code' => code1, 'amount' => amount1 }
          res1 << { 'code' => consumption_code, 'amount' => consumption_amount } if consumption_idx == 0
        end
        res << [].tap do |res2|
          amount2 = amount
          amount2 -= consumption_amount if consumption_idx == 1
          res2 << { 'code' => code2, 'amount' => amount2 }
          res2 << { 'code' => consumption_code, 'amount' => consumption_amount } if consumption_idx == 1
        end
      end
    end
  end
end
