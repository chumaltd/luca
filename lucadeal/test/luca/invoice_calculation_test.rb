require_relative '../test_helper'
require 'luca/io'
require 'luca_deal'
require 'fileutils'
require 'pathname'

class Luca::InvoiceCalcurationTest < Minitest::Test
  include Luca::IO

  def setup
    @test_id = issue_random_id
    @current_dir = FileUtils.pwd
    @test_dir = Pathname('tmp') / @test_id
    FileUtils.mkdir_p(@test_dir)
    FileUtils.chdir(@test_dir)
    LucaDeal::Setup.create_project('.')
  end

  def teardown
    FileUtils.chdir(@current_dir)
    FileUtils.rm_rf(@test_dir)
  end

  def test_that_it_create_correct_amount
    generate_valid_contract('Test Corporation1')
    @invoice = LucaDeal::Invoice.new('2020-3-3')
    dat = { 'customer' => 'TestCompany', 'subtotal' => [{ 'rate' => 'default', 'items' => 9_999, 'tax' => 999 }] }
    @invoice.set_invoice_vars(dat)

    assert_equal 'TestCompany', @invoice.instance_variable_get(:@customer)
    assert_equal 10_998, @invoice.instance_variable_get(:@amount)

    dat = { 'customer' => 'TestCompany',
            'subtotal' => [
              { 'rate' => 'default', 'items' => 9_999, 'tax' => 999 },
              { 'rate' => 'default', 'items' => 777_777_777_777_777, 'tax' => 70_000_000_000 }
            ] }
    @invoice.set_invoice_vars(dat)

    assert_equal 777_847_777_788_775, @invoice.instance_variable_get(:@amount)
  end
end
