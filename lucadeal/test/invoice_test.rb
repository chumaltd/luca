# frozen_string_literal: true

require_relative 'test_helper'

class LucaDeal::InvoiceTest < Minitest::Test
  include LucaRecord::IO

  def setup
    FileUtils.chdir(LucaSupport::Config::Pjdir)
    LucaDeal::Setup.create_project(LucaSupport::Config::Pjdir)
  end

  def teardown
    FileUtils.rm_rf(['data', 'config.yml'])
  end

  def test_that_it_create_no_duplication
    backup = 'initial_invoice.backup'
    generate_valid_contract('Test Company')
    LucaDeal::Invoice.new('2020-3-3').monthly_invoice
    @invoices1 = Dir.glob('data/invoices/*/*').first
    FileUtils.cp @invoices1, backup

    LucaDeal::Invoice.new('2020-3-3').monthly_invoice
    @invoices2 = Dir.glob('data/invoices/*/*').first
    assert_equal @invoices1.length, @invoices2.length
    assert FileUtils.identical?(backup, @invoices2)
    FileUtils.rm(backup)
  end

  def test_that_it_create_item_buy
    customer_id = LucaDeal::Customer.create({name: 'Test Company'})
    LucaDeal::Contract.create({ 'customer_id' => customer_id,
                                'terms' => {
                                  'effective' => '2020-2-1',
                                  'billing_cycle' => 'monthly'
                                },
                                'items' => [
                                  { 'name' => 'Custom Service', 'price' => 500 }
                                ]})
    LucaDeal::Invoice.new('2020-3-3').monthly_invoice
    assert_equal 1, LucaDeal::Invoice.all.count
    LucaDeal::Invoice.asof(2020, 3) do |invoice|
      assert_equal 1, invoice['items'].length
      assert_equal 'Custom Service', invoice['items'][0]['name']
      assert_equal 500, invoice['items'][0]['price']
      assert_nil invoice['items'][0]['product_id']
    end
  end

  def test_that_it_create_product_buy
    customer_id = LucaDeal::Customer.create({name: 'Test Company'})
    product_id = LucaDeal::Product.create(name: 'Premium Subscription', price: 2000)
    LucaDeal::Contract.create({ 'customer_id' => customer_id,
                                              'terms' => {
                                                'effective' => '2020-2-1',
                                                'billing_cycle' => 'monthly'
                                              },
                                              'products' => [
                                                { 'id' => product_id }
                                              ]})
    LucaDeal::Invoice.new('2020-3-3').monthly_invoice
    assert_equal 1, LucaDeal::Invoice.all.count
    LucaDeal::Invoice.asof(2020, 3) do |invoice|
      assert_equal 1, invoice['items'].length
      assert_equal 'Premium Subscription', invoice['items'][0]['name']
      assert_equal 2000, invoice['items'][0]['price']
      assert_equal product_id, invoice['items'][0]['product_id']
    end
  end

  def test_that_it_create_product_buy_with_custom_item
    customer_id = LucaDeal::Customer.create({name: 'Test Company'})
    product_id = LucaDeal::Product.create(name: 'Premium Subscription', price: 2000)
    LucaDeal::Contract.create({ 'customer_id' => customer_id,
                                              'terms' => {
                                                'effective' => '2020-2-1',
                                                'billing_cycle' => 'monthly'
                                              },
                                              'products' => [
                                                { 'id' => product_id }
                                              ],
                                              'items' => [
                                                { 'name' => 'Custom Option Service', 'price' => 500 }
                                              ]})
    LucaDeal::Invoice.new('2020-3-3').monthly_invoice
    assert_equal 1, LucaDeal::Invoice.all.count
    LucaDeal::Invoice.asof(2020, 3) do |invoice|
      assert_equal 2, invoice['items'].length
      assert invoice['items'].map { |i| i['name'] }.include?('Premium Subscription')
      assert invoice['items'].map { |i| i['name'] }.include?('Custom Option Service')
      assert invoice['items'].map { |i| i['price'] }.include?(2000)
      assert invoice['items'].map { |i| i['price'] }.include?(500)
    end
  end
end
