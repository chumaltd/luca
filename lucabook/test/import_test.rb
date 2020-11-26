# frozen_string_literal: true

require_relative 'test_helper'

class LucaBook::ImportTest < Minitest::Test
  include LucaRecord::IO

  def setup
    FileUtils.chdir(LucaSupport::PJDIR)
    LucaBook::Setup.create_project(LucaSupport::PJDIR)
    deploy('import-bank1.yaml', 'dict')
    deploy('sample-bankstatement.csv')
  end

  def teardown
    FileUtils.rm_rf(['data', 'dict', 'sample-bankstatement.csv'])
  end

  def test_that_it_create_journals
    LucaBook::Import.new('sample-bankstatement.csv', 'bank1').import_csv
    assert_equal 4, Dir.glob('data/journals/9999L/*').length
    assert_equal 1, Dir.glob('data/journals/9999L/9001').length
    assert_equal 1, Dir.glob('data/journals/9999L/F001').length
    assert_equal 1, Dir.glob('data/journals/9999L/F002').length
    assert_equal 1, Dir.glob('data/journals/9999L/V001').length
    LucaBook::Journal.asof(9999, 12, 9).each do |dat|
      assert_equal BigDecimal('98.99'), dat[:debit][0][:amount]
      assert_equal BigDecimal('98.99'), dat[:credit][0][:amount]
      assert_equal '1101', dat[:debit][0][:code]
      assert_equal 'D11', dat[:credit][0][:code]
    end
    assert_equal 2, File.read('data/journals/9999L/9001').match(/(98\.99)/).size
    assert_equal 0, Dir.glob('data/journals/9999L/*-*113*').length
  end

  def test_that_it_create_code_index
    LucaBook::Import.new('sample-bankstatement.csv', 'bank1').import_csv
    LucaBook::Journal.asof(9999, 12).each do |dat|
      LucaBook::Journal.update_codes dat
    end
    assert_equal 4, Dir.glob('data/journals/9999L/*').length
    assert_equal 4, Dir.glob('data/journals/9999L/*-*1101*').length
    assert_equal 1, Dir.glob('data/journals/9999L/*-*511*').length
    assert_equal 1, Dir.glob('data/journals/9999L/*-*514*').length
    assert_equal 1, Dir.glob('data/journals/9999L/*-*C1E*').length
    assert_equal 1, Dir.glob('data/journals/9999L/*-*D11*').length
  end
end
