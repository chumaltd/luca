# frozen_string_literal: true

require_relative 'test_helper'

class LucaDeal::CustomerTest < Minitest::Test
  include LucaRecord::IO

  def setup
    FileUtils.chdir(LucaSupport::Config::Pjdir)
    LucaDeal::Setup.create_project(LucaSupport::Config::Pjdir)
  end

  def teardown
    FileUtils.rm_rf(['data', 'config.yml'])
  end

  def test_that_it_create_multiple_customers
    customer_id = LucaDeal::Customer.create(name: 'SampleCustomer co.', address: 'Shibuya', address2: 'Tokyo')
    assert_equal 1, Dir.glob('data/customers/*/*').length
    assert_equal 1, LucaDeal::Customer.all.count
    load_data = LucaDeal::Customer.find(customer_id).first
    assert_equal 'SampleCustomer co.', load_data['name']
    assert_equal 'Shibuya', load_data['address']
    assert_equal 'Tokyo', load_data['address2']
    LucaDeal::Customer.create(name: 'SampleCustomer co.', address: 'Shibuya', address2: 'Tokyo')
    assert_equal 2, Dir.glob('data/customers/*/*').length
    assert_equal 2, LucaDeal::Customer.all.count
  end
end
