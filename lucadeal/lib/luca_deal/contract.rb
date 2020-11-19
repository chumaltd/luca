# frozen_string_literal: true

require 'luca_deal/version'

require 'yaml'
require 'pathname'
require 'luca_record'

module LucaDeal
  class Contract < LucaRecord::Base
    @dirname = 'contracts'
    @required = ['customer_id', 'terms']

    def initialize(date = nil)
      @date = date ? Date.parse(date) : Date.today
      @pjdir = Pathname(Dir.pwd)
    end

    # returns active contracts on specified date.
    #
    def self.asof(year, month, day)
      return enum_for(:asof, year, month, day) unless block_given?

      new("#{year}-#{month}-#{day}").active do |contract|
        yield contract
      end
    end

    #
    # collect active contracts
    #
    def active
      return enum_for(:active) unless block_given?

      self.class.all do |data|
        next if !active_period?(data.dig('terms'))

        contract = parse_current(data)
        contract['items'] = contract['items']&.map { |item| parse_current(item) }
        # TODO: handle sales_fee rate change
        contract['rate'] = contract['rate']
        yield contract.compact
      end
    end

    def describe(id)
      contract = parse_current(self.class.find(id))
      if contract['products']
        contract['products'] = contract['products'].map do |product|
          LucaDeal::Product.find(product['id'])
        end
      end
      YAML.dump(readable(contract)).tap{ |d| puts d }
    end

    def generate!(customer_id, mode = 'subscription')
      LucaDeal::Customer.find(customer_id) do |customer|
        current_customer = parse_current(customer)
        if mode == 'sales_fee'
          obj = salesfee_template
        else
          obj = monthly_template
        end
        obj.merge!({ 'customer_id' => current_customer['id'], 'customer_name' => current_customer['name'] })
        obj['terms'] ||= {}
        obj['terms']['effective'] = @date
        self.class.create(obj)
      end
    end

    def active_period?(dat)
      unless dat.dig('defunct').nil?
        defunct = dat.dig('defunct').respond_to?(:year) ? dat.dig('defunct') : Date.parse(dat.dig('defunct'))
        return false if @date > defunct
      end
      effective = dat.dig('effective').respond_to?(:year) ? dat.dig('effective') : Date.parse(dat.dig('effective'))
      @date >= effective
    end

    private

    def monthly_template
      {}.tap do |obj|
        obj['items'] = [{
                          'name' => '_ITEM_NAME_FOR_INVOICE_',
                          'qty' => 1,
                          'price' => 0
                        }]
        obj['terms'] = { 'billing_cycle' => 'monthly' }
      end
    end

    def salesfee_template
      {}.tap do |obj|
        obj['rate'] = {
          'default' => '0.2',
          'initial' => '0.2'
        }
        obj['terms'] = { 'category' => 'sales_fee' }
      end
    end
  end
end
