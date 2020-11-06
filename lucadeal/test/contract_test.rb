# frozen_string_literal: true

require_relative 'test_helper'

class LucaDeal::ContractTest < Minitest::Test
  include LucaRecord::IO

  def setup
    FileUtils.chdir(LucaSupport::Config::Pjdir)
    LucaDeal::Setup.create_project(LucaSupport::Config::Pjdir)
  end

  def teardown
    FileUtils.rm_rf(['data', 'config.yml'])
  end

  def test_that_it_create_multiple_contracts
    customer_id = LucaDeal::Customer.create(name: 'Customer Co.')
    LucaDeal::Contract.new('2020-3-1').generate!(customer_id)
    assert_equal 1, LucaDeal::Contract.all.count
    LucaDeal::Contract.new('2020-4-1').generate!(customer_id)
    assert_equal 2, LucaDeal::Contract.all.count
    assert_equal 0, LucaDeal::Contract.asof(2020, 2, 1).count
    assert_equal 1, LucaDeal::Contract.asof(2020, 3, 15).count
    assert_equal 2, LucaDeal::Contract.asof(2020, 5, 1).count
  end

  def test_that_it_create_multiple_salesfee_contracts
    customer_id = LucaDeal::Customer.create(name: 'Sales Partner Co.')
    LucaDeal::Contract.new('2020-3-1').generate!(customer_id, 'sales_fee')
    assert_equal 1, LucaDeal::Contract.all.count
    LucaDeal::Contract.new('2020-4-1').generate!(customer_id, 'sales_fee')
    assert_equal 2, LucaDeal::Contract.all.count
    assert_equal 0, LucaDeal::Contract.asof(2020, 2, 1).count
    assert_equal 1, LucaDeal::Contract.asof(2020, 3, 15).count
    assert_equal 2, LucaDeal::Contract.asof(2020, 5, 1).count
  end
end
