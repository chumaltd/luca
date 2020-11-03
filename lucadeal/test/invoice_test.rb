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
end
