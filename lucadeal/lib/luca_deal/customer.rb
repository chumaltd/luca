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

    def initialize
      @date = Date.today
    end

    def list_name
      self.class.all.map { |dat| parse_current(dat).sort.to_h }
    end

    def describe(id)
      customer = parse_current(self.class.find(id))
      contracts = Contract.all.select { |contract| contract['customer_id'] == customer['id'] }
      if !contracts.empty?
        customer['contracts'] = contracts.map do |c|
          {
            'id' => c['id'],
            'effective' => c['terms']['effective'],
            'defunct' => c['terms']['defunct']
          }
        end
      end
      readable(customer)
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
