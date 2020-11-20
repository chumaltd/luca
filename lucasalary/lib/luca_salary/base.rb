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
      @pjdir = Pathname(LucaSupport::Config::Pjdir)
      @config = load_config(@pjdir / 'config.yml')
      @dict = load_dict
    end

    def gen_aggregation!
      LucaSalary::Profile.all do |profile|
        id = profile.dig('id')
        payment = {}
        targetdir = @date.year.to_s + 'Z'
        past_data = LucaRecord::Base.find(id, "payments/#{targetdir}")
        (1..12).map do |month|
          origin_dir = @date.year.to_s + [nil, 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'][month]
          origin = LucaRecord::Base.find(id, "payments/#{origin_dir}")
          # TODO: to be updated null check
          if origin == {}
            month
          else
            origin.select { |k, _v| /^[1-4][0-9A-Fa-f]{,3}$/.match(k) }.each do |k, v|
              payment[k] = payment[k] ? payment[k] + v : v
            end
            nil
          end
        end
        self.class.create(past_data.merge!(payment), "payments/#{targetdir}")
      end
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
          h[code] = sum_code(obj, code)
        end
        h['5'] = h['1'] - h['2'] - h['3'] + h['4']
      end
    end

    def sum_code(obj, code, exclude = nil)
      target = obj.select { |k, _v| /^#{code}[0-9A-Fa-f]{,3}$/.match(k) }
      target = target.reject { |k, _v| exclude.include?(k) } if exclude
      target.values.inject(:+) || 0
    end

    private

    def datadir
      @pjdir / 'data'
    end

    def load_dict
      LucaRecord::Dict.load_tsv_dict(@pjdir / 'dict' / 'code.tsv')
    end

    def set_driver
      code = @config['countryCode']
      if code
        require "luca_salary/#{code.downcase}"
        Kernel.const_get "LucaSalary::#{code.upcase}"
      else
        nil
      end
    end
  end
end
