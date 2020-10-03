require 'luca_salary/version'

require 'date'
require 'yaml'
require 'pathname'
require 'luca_salary/fileop'
require 'luca_record'

module LucaSalary
  class Base < LucaRecord::Base
    attr_reader :driver, :dict, :config, :pjdir
    @dirname = 'payments'

    def initialize(date = nil)
      @date = date.nil? ? Date.today : Date.parse(date)
      @pjdir = Pathname(Dir.pwd)
      @config = load_config(@pjdir + 'config.yml')
      @driver = set_driver
      @dict = @driver.load_dict
    end

    def self.load_dict
      load_dict_tsv(country_path)
    end

    def calc
      self.class.prepare_dir!(datadir / 'payments', @date)
      country = @driver.new(@pjdir, @config, @date)
      load_profiles do |profile|
        h = country.calc_payment(profile)
        gen_payment!(profile, h)
      end
    end

    def gen_payment!(profile, payment)
      id = profile.dig('id')
      if self.class.search(@date.year, @date.month, @date.day, id)
        puts 'payment record already exists.'
        return nil
      end

      payment_dir = (datadir + 'payments').to_s
      gen_record_file!(payment_dir, @date, Array(id)) do |f|
        f.write(YAML.dump(payment.sort.to_h))
      end
    end

    def gen_aggregation!
      load_profiles do |profile|
        id = profile.dig('id')
        payment = {}
        targetdir = @date.year.to_s + 'Z'
        past_data = LucaRecord::Base.find(id, "payments/#{targetdir}").first
        nodata = (1..12).map do |month| 
          origin_dir = @date.year.to_s + [nil, 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'][month]
          origin = LucaRecord::Base.find(id, "payments/#{origin_dir}").first
          # TODO: to be updated null check
          if origin == {}
            month
          else
            origin.select { |k, v| /^[1-4][0-9A-Fa-f]{,3}$/.match(k) }.each do |k, v|
              payment[k] = payment[k] ? payment[k] + v : v
            end
            nil
          end
        end
        LucaRecord::Base.open_hashed("payments/#{targetdir}", id, 'w') do |f|
          f.write(YAML.dump(past_data.merge!(payment).sort.to_h))
        end
      end
    end

    def select_code(dat, code)
      {}.tap do |h|
        dat.keys.filter { |k| /^#{code}[0-9A-Fa-f]{,3}$/.match(k.to_s) }.map do |k|
          h[k.to_s] = take_active(dat, k)
        end
      end
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

    def load_profiles
      [].tap do |a|
        open_profiles do |f, name|
          data = YAML.load(f.read)
          yield data
        end
      end
    end

    def open_profiles
      match_files = datadir + 'profiles' + "*" + "*"
      Dir.glob(match_files.to_s).each do |file_name|
        File.open(file_name, 'r') { |f| yield(f, file_name) }
      end
    end

    def datadir
      Pathname(@pjdir) + 'data'
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
