# frozen_string_literal: true

require_relative './test_helper'

class LucaDeal::InvoiceCalcurationTest < Minitest::Test
  include LucaRecord::IO

  def setup
    FileUtils.chdir(LucaSupport::CONST.pjdir)
    LucaDeal::Setup.create_project(LucaSupport::CONST.pjdir)
  end

  def teardown
    FileUtils.rm_rf(['data', 'config.yml'])
  end

  def test_that_it_create_correct_amount
    generate_valid_contract('Test Corporation1')
    @invoice = LucaDeal::Invoice.new('2020-3-3')
    dat = { 'customer' => 'TestCompany', 'subtotal' => [{ 'rate' => 'default', 'items' => 9_999, 'tax' => 999 }] }
    @invoice.send(:invoice_vars, dat)

    assert_equal 'TestCompany', @invoice.instance_variable_get(:@customer)
    assert_equal 10_998, @invoice.instance_variable_get(:@amount)

    dat = { 'customer' => 'TestCompany',
            'subtotal' => [
              { 'rate' => 'default', 'items' => 9_999, 'tax' => 999 },
              { 'rate' => 'default', 'items' => 777_777_777_777_777, 'tax' => 70_000_000_000 }
            ] }
    @invoice.send(:invoice_vars, dat)

    assert_equal 777_847_777_788_775, @invoice.instance_variable_get(:@amount)
  end
end
