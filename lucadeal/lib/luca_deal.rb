# frozen_string_literal: true

require 'luca_record'
require 'luca_deal/version'

module LucaDeal
  autoload :Customer, 'luca_deal/customer'
  autoload :Contract, 'luca_deal/contract'
  autoload :Fee, 'luca_deal/fee'
  autoload :Invoice, 'luca_deal/invoice'
  autoload :Product, 'luca_deal/product'
  autoload :Setup, 'luca_deal/setup'
end
