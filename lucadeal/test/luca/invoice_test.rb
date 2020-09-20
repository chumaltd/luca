require_relative '../test_helper'
require 'luca/io'
require 'luca_deal'
require 'fileutils'
require 'pathname'

class Luca::InvoiceTest < Minitest::Test
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

  def test_that_it_create_no_duplication
    generate_valid_contract('Test Corporation1')
    LucaDeal::Invoice.new('2020-3-3').monthly_invoice
    @invoices1 = Pathname.glob('data/invoices/*/*')
    FileUtils.cp @invoices1.first, 'initial_invoice.backup'

    LucaDeal::Invoice.new('2020-3-3').monthly_invoice
    @invoices2 = Pathname.glob('data/invoices/*/*')
    assert_equal @invoices1.length, @invoices2.length
    assert FileUtils.identical?('initial_invoice.backup', @invoices2.first)
  end
end
