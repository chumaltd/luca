# frozen_string_literal: true

require 'date'
require 'pathname'
require 'mail'
require 'yaml'
require 'luca_support/mail'
require 'luca_salary'
require 'luca_record'

module LucaSalary
  class Monthly < LucaSalary::Base
    @dirname = 'payments'

    def initialize(date = nil)
      @date = date.nil? ? Date.today : Date.parse(date)
      @pjdir = Pathname(LucaRecord::CONST.pjdir)
      @config = load_config(@pjdir + 'config.yml')
      @driver = set_driver
    end

    # call country specific calculation
    #
    def calc
      country = @driver.new(@pjdir, @config, @date)
      # TODO: handle retirement
      LucaSalary::Profile.all do |profile|
        current_profile = parse_current(Profile.find_secure(profile['id']))
        if self.class.search(@date.year, @date.month, @date.day, current_profile['id']).count > 0
          puts "payment record already exists: #{current_profile['id']}"
          return nil
        end
        h = country.calc_payment(current_profile, @date)
        h['profile_id'] = current_profile['id']
        self.class.create(h, date: @date, codes: Array(current_profile['id']))
      end
    end

    # output payslips via mail or console
    #
    def report(mode = nil)
      data = LucaSalary::Payment.new(@date.to_s).payslip
      if mode == 'mail'
        mail = Mail.new do
          subject '[luca salary] Monthly Payment'
        end
        mail.to = @config.dig('mail', 'report_mail')
        mail.text_part = YAML.dump(LucaSupport::Code.readable(data))
        LucaSupport::Mail.new(mail, @pjdir).deliver
      else
        LucaSupport::Code.readable(data)
      end
    end

    private

    def parse_date(date = nil)
      date.nil? ? Date.today : Date.parse(date)
    end
  end
end
