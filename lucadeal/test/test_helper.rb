# frozen_string_literal: true

require 'bundler'
Bundler.require

require 'simplecov'
SimpleCov.start

require 'fileutils'
require 'pathname'
require 'luca_deal'
require 'luca_record/io'

require 'minitest/autorun'

def generate_valid_contract(customer_name)
  @customer_id = LucaDeal::Customer.create({name: customer_name})
  @contradt_id = LucaDeal::Contract.new('2020-2-20').generate!(@customer_id)
end
