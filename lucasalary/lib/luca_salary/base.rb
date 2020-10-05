require 'luca_salary/version'

require 'date'
require 'yaml'
require 'pathname'
require 'luca_support'
require 'luca_salary'
require 'luca_record'

module LucaSalary
  class Base < LucaRecord::Base
    attr_reader :driver, :dict, :config, :pjdir
    @dirname = 'payments'

    def initialize(date = nil)
      @date = date.nil? ? Date.today : Date.parse(date)
      @pjdir = Pathname(LucaSupport::Config::Pjdir)
      @config = load_config(@pjdir + 'config.yml')
      @driver = set_driver
      @dict = load_dict
    end

    #
    # call country specific calculation
    #
    def calc
      self.class.prepare_dir!(datadir / 'payments', @date)
      country = @driver.new(@pjdir, @config, @date)
      LucaSalary::Profile.all do |profile|
        current_profile = parse_current(profile)
        h = country.calc_payment(current_profile)
        LucaSalary::Payment.new(@date.to_s).create(current_profile, h)
      end
    end

    def gen_aggregation!
      LucaSalary::Profile.all do |profile|
        id = profile.dig('id')
        payment = {}
        targetdir = @date.year.to_s + 'Z'
        past_data = LucaRecord::Base.find(id, "payments/#{targetdir}").first
        (1..12).map do |month|
          origin_dir = @date.year.to_s + [nil, 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'][month]
          origin = LucaRecord::Base.find(id, "payments/#{origin_dir}").first
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

    def amount_by_code(obj)
      {}.tap do |h|
        (1..4).each do |n|
          h["#{n}00"] = sum_code(obj, n)
        end
      end
    end

    def sum_code(obj, code, exclude = nil)
      target = obj.select { |k, v| /^#{code}[0-9A-Fa-f]{,3}$/.match(k) }
      target = target.reject { |k, v| exclude.include?(k) } if exclude
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
        Kernel.const_get "LucaSalary#{code.upcase}"
      else
        nil
      end
    end
  end
end
