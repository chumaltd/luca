# frozen_string_literal: true

require 'date'
require 'pathname'
require 'mail'
require 'yaml'
require 'luca_support/mail'
require 'luca_salary'
require 'luca_record'

module LucaSalary
  class Monthly < LucaRecord::Base
    def initialize(date = nil)
      @date = parse_date(date)
      @pjdir = Pathname(LucaSupport::Config::Pjdir)
      @config = load_config(@pjdir + 'config.yml')
    end

    #
    # output payslips via mail or console
    #
    def report(mode = nil)
      if mode == 'mail'
        mail = Mail.new do
          subject '[luca salary] Monthly Payment'
        end
        mail.to = @config.dig('mail', 'report_mail')
        mail.text_part = YAML.dump(LucaSalary::Payment.new(@date.to_s).payslip)
        LucaSupport::Mail.new(mail, @pjdir).deliver
      else
        puts YAML.dump(LucaSalary::Payment.new(@date.to_s).payslip)
      end
    end

    private

    def parse_date(date = nil)
      date.nil? ? Date.today : Date.parse(date)
    end
  end
end
