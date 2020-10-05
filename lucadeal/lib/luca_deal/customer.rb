# frozen_string_literal: true

require 'luca_deal/version'

require 'date'
require 'yaml'
require 'pathname'
require 'luca_record'

module LucaDeal
  class Customer < LucaRecord::Base
    @dirname = 'customers'

    def initialize(pjdir = nil)
      @date = Date.today
      @pjdir = pjdir || Dir.pwd
    end

    def list_name
      list = self.class.all.map { |dat| parse_current(dat) }
      YAML.dump(list).tap { |l| puts l }
    end

    def generate!(name)
      contact = {
        'mail' => '_MAIL_ADDRESS_FOR_CONTACT_'
      }
      obj = {
        'name' => name,
        'address' => '_CUSTOMER_ADDRESS_FOR_INVOICE_',
        'address2' => '_CUSTOMER_ADDRESS_FOR_INVOICE_',
        'contacts' => [contact]
      }
      self.class.create(obj)
    end
  end
end
