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
      data = LucaSalary::Payment.new(@date.to_s).payslip
      if mode == 'mail'
        mail = Mail.new do
          subject '[luca salary] Monthly Payment'
        end
        mail.to = @config.dig('mail', 'report_mail')
        mail.text_part = YAML.dump(LucaSupport::Code.readable(data))
        LucaSupport::Mail.new(mail, @pjdir).deliver
      else
        puts YAML.dump(LucaSupport::Code.readable(data))
      end
    end

    private

    def parse_date(date = nil)
      date.nil? ? Date.today : Date.parse(date)
    end
  end
end
