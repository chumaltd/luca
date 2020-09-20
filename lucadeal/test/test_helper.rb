$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'luca_deal'

require 'minitest/autorun'

def generate_valid_contract(customer_name)
  @customer_id = LucaDeal::Customer.new.generate!(customer_name)
  @contradt_id = LucaDeal::Contract.new('2020-2-20').generate!(@customer_id)
end
