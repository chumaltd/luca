require 'luca_deal/version'

require 'yaml'
require 'pathname'
require 'luca_record'

module LucaDeal
  class Contract < LucaRecord::Base
    @dirname = 'contracts'

    def initialize(date = nil)
      @date = date ? Date.parse(date) : Date.today
      @pjdir = Pathname(Dir.pwd)
    end

    #
    # collect active contracts
    #
    def active
      self.class.all do |data|
        contract = parse_current(data)
        contract['items'] = contract['items'].map { |item| parse_current(item) }
        next if !active_period?(contract.dig('terms'))

        yield contract
      end
    end

    def generate!(customer_id, mode = nil)
      LucaDeal::Customer.find(customer_id) do |customer|
        current_customer = parse_current(customer)
        obj = { 'customer_id' => current_customer['id'], 'customer_name' => current_customer['name'] }
        obj['terms'] = { 'effective' => @date }
        if mode == 'sales_fee'
          obj.merge! salesfee_template
        else
          obj.merge! monthly_template
        end
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
