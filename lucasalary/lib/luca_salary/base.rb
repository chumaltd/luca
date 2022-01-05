require 'luca_salary/version'

require 'date'
require 'yaml'
require 'pathname'
require 'luca_support'
require 'luca_salary'
require 'luca_record'

module LucaSalary
  class Base < LucaRecord::Base
    attr_reader :dict, :config, :pjdir
    @dirname = 'payments'

    def initialize(date = nil)
      @date = date.nil? ? Date.today : Date.parse(date)
      @dict = load_dict
    end

    def select_code(dat, code)
      dat.filter { |k, _v| /^#{code}[0-9A-Fa-f]{,3}$/.match(k.to_s) }
    end

    # Subtotal each items.
    # 1::
    #    Base salary or wages.
    # 2::
    #    Deduction directly related to work payment, including tax, insurance, pension and so on.
    # 3::
    #    Deduction for miscellaneous reasons.
    # 4::
    #    Addition for miscellaneous reasons.
    # 5::
    #    Net payment amount.
    #
    def amount_by_code(obj)
      {}.tap do |h|
        (1..4).each do |n|
          code = n.to_s
          h[code] = self.class.sum_code(obj, code)
        end
        h['5'] = h['1'] - h['2'] - h['3'] + h['4']
      end
    end

    def self.sum_code(obj, code, exclude = nil)
      target = obj.select { |k, _v| /^#{code}[0-9A-Fa-f]{,3}$/.match(k) }
      target = target.reject { |k, _v| exclude.include?(k) } if exclude
      target.values.inject(:+) || 0
    end

    private

    def load_dict
      LucaRecord::Dict.load_tsv_dict(Pathname(PJDIR) / 'dict' / 'code.tsv')
    end

    def set_driver
      code = CONFIG['country']
      if code
        require "luca_salary/#{code.downcase}"
        Kernel.const_get "LucaSalary::#{code.capitalize}"
      else
        nil
      end
    end
  end
end
