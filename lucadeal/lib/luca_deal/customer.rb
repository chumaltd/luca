# frozen_string_literal: true

require 'luca_deal/version'

require 'date'
require 'yaml'
require 'pathname'
require 'luca_record'

module LucaDeal
  class Customer < LucaRecord::Base
    @dirname = 'customers'
    @required = ['name']

    def initialize(pjdir = nil)
      @date = Date.today
      @pjdir = pjdir || Dir.pwd
    end

    def list_name
      list = self.class.all.map { |dat| parse_current(dat).sort.to_h }
      YAML.dump(list).tap { |l| puts l }
    end

    def describe(id)
      customer = parse_current(self.class.find(id))
      contracts = LucaDeal::Contract.all.select { |contract| contract['customer_id'] == customer['id'] }
      if !contracts.empty?
        customer['contracts'] = contracts.map do |c|
          {
            'id' => c['id'],
            'effective' => c['terms']['effective'],
            'defunct' => c['terms']['defunct']
          }
        end
      end
      YAML.dump(readable(customer)).tap{ |d| puts d }
    end

    def self.create(obj)
      raise ':name is required' if obj[:name].nil?

      contacts = obj[:contact]&.map { |c| { 'mail' => c[:mail] } }&.compact
      contacts ||= [{
        'mail' => '_MAIL_ADDRESS_FOR_CONTACT_'
      }]
      h = {
        'name' => obj[:name],
        'address' => obj[:address] || '_CUSTOMER_ADDRESS_FOR_INVOICE_',
        'address2' => obj[:address2] || '_CUSTOMER_ADDRESS_FOR_INVOICE_',
        'contacts' => contacts
      }
      super(h)
    end
  end
end
