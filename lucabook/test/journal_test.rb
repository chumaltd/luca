# frozen_string_literal: true

require_relative 'test_helper'

class LucaBook::JournalTest < Minitest::Test
  include LucaRecord::IO

  def setup
    FileUtils.chdir(LucaSupport::PJDIR)
    LucaBook::Setup.create_project(LucaSupport::PJDIR)
  end

  def teardown
    FileUtils.rm_rf(['data', 'dict'])
  end

  def test_that_it_create_then_save_journals
    journal = {
      date: '9999-12-9',
      debit: [
        { code: 'C1E', value: BigDecimal('98.76') }
      ],
      credit: [
        { code: '113', value: BigDecimal('98.76') }
      ],
      note: 'test journal'
    }
    LucaBook::Journal.create(journal)
    assert_equal 1, Dir.glob('data/journals/9999L/9001').length
    LucaBook::Journal.asof(9999, 12, 9).each do |dat|
      assert_equal BigDecimal('98.76'), dat[:debit][0][:amount]
      assert_equal BigDecimal('98.76'), dat[:credit][0][:amount]
      assert_equal 'C1E', dat[:debit][0][:code]
      assert_equal '113', dat[:credit][0][:code]
    end
    journal = {
      id: '9999L/9001',
      debit: [
        { code: 'C1E', value: BigDecimal('198.76') }
      ],
      credit: [
        { code: '113', value: BigDecimal('198.76') }
      ],
      note: 'test journal'
    }
    LucaBook::Journal.save(journal)
    assert_equal 1, Dir.glob('data/journals/9999L/9001').length
    LucaBook::Journal.asof(9999, 12, 9).each do |dat|
      assert_equal BigDecimal('198.76'), dat[:debit][0][:amount]
      assert_equal BigDecimal('198.76'), dat[:credit][0][:amount]
      assert_equal 'C1E', dat[:debit][0][:code]
      assert_equal '113', dat[:credit][0][:code]
    end
  end

  def test_that_it_doesnot_save_journals_with_no_id
    journal = {
      date: '9999-12-9',
      debit: [
        { code: 'C1E', value: BigDecimal('98.76') }
      ],
      credit: [
        { code: '113', value: BigDecimal('98.76') }
      ],
      headers: { 'x-customer' => 'Test Co.' },
      note: 'test journal'
    }
    LucaBook::Journal.create(journal)
    journal = {
      debit: [
        { code: 'C1E', value: BigDecimal('198.76') }
      ],
      credit: [
        { code: '113', value: BigDecimal('198.76') }
      ],
      note: 'test journal'
    }
    assert_raises do
      LucaBook::Journal.save(journal)
    end
    assert_equal 1, Dir.glob('data/journals/9999L/9001').length
    LucaBook::Journal.asof(9999, 12, 9).each do |dat|
      assert_equal BigDecimal('98.76'), dat[:debit][0][:amount]
      assert_equal BigDecimal('98.76'), dat[:credit][0][:amount]
      assert_equal 'C1E', dat[:debit][0][:code]
      assert_equal '113', dat[:credit][0][:code]
      assert_equal 'Test Co.', dat[:headers]['x-customer']
    end
  end
end
