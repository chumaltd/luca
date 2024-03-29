# frozen_string_literal: true

require_relative 'test_helper'

class LucaDeal::ProductTest < Minitest::Test
  include LucaRecord::IO

  def setup
    FileUtils.chdir(LucaSupport::CONST.pjdir)
    LucaDeal::Setup.create_project(LucaSupport::CONST.pjdir)
  end

  def teardown
    FileUtils.rm_rf(['data', 'config.yml'])
  end

  def test_that_it_create_multiple_products
    product_id = LucaDeal::Product.create(name: 'SampleProduct1', price: 30000, initial: { name: 'Initial fee', price: 50000 })
    assert_equal 1, LucaDeal::Product.all.count
    load_data = LucaDeal::Product.find(product_id)
    assert_equal 30000, load_data['items'][0]['price']
    assert_equal 'SampleProduct1', load_data['items'][0]['name']
    assert_equal 50000, load_data['items'][1]['price']
    assert_equal 'initial', load_data['items'][1]['type']
    LucaDeal::Product.create(name: 'SampleProduct1', price: 30000, initial: { name: 'Initial fee', price: 50000 })
    assert_equal 2, LucaDeal::Product.all.count
  end

  def test_that_it_raise_on_incompleted_data
    assert_raises { |_| LucaDeal::Product.create({ 'name' => 'Invalid Product' }) }
    product_id = LucaDeal::Product.create(name: 'SampleProduct1', price: 30000, initial: { name: 'Initial fee', price: 50000 })
    assert_raises { |_| LucaDeal::Product.save({ 'id' => product_id, 'name' => 'Invalid Product' }) }
    load_data = LucaDeal::Product.find(product_id)
    assert_equal 30000, load_data['items'][0]['price']
    assert_equal 'SampleProduct1', load_data['items'][0]['name']
    assert_equal 50000, load_data['items'][1]['price']
    assert_equal 'initial', load_data['items'][1]['type']
  end
end
