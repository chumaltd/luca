# frozen_string_literal: true

require_relative 'test_helper'
require 'date'

class LucaSupport::CodeTest < Minitest::Test
  def test_encode_txid
    assert_equal '000', LucaSupport::Code.encode_txid(0)
    assert_equal '7PR', LucaSupport::Code.encode_txid(9999)
  end

  def test_decode_txid
    assert_equal 0, LucaSupport::Code.decode_txid('000')
    assert_equal 9999, LucaSupport::Code.decode_txid('7PR')
  end

  def test_encode_date
    assert_equal 'V', LucaSupport::Code.encode_date(Date.parse('9999-12-31'))
    assert_equal '1', LucaSupport::Code.encode_date(1)
    assert_equal 'A', LucaSupport::Code.encode_date(10)
    assert_equal 'V', LucaSupport::Code.encode_date(31)
    assert_raises { |_| LucaSupport::Code.encode_date(0) }
    assert_raises { |_| LucaSupport::Code.encode_date(32) }
    assert_equal '', LucaSupport::Code.encode_date(nil)
  end

  def test_decode_date
    assert_equal 1, LucaSupport::Code.decode_date('1')
    assert_equal 10, LucaSupport::Code.decode_date('A')
    assert_equal 31, LucaSupport::Code.decode_date('V')
    assert_nil LucaSupport::Code.decode_date('W')
  end

  def test_encode_month
    assert_equal 'A', LucaSupport::Code.encode_month(Date.parse('9999-1-1'))
    assert_equal 'A', LucaSupport::Code.encode_month(1)
    assert_equal 'B', LucaSupport::Code.encode_month(2)
    assert_equal 'C', LucaSupport::Code.encode_month(3)
    assert_equal 'D', LucaSupport::Code.encode_month(4)
    assert_equal 'E', LucaSupport::Code.encode_month(5)
    assert_equal 'F', LucaSupport::Code.encode_month(6)
    assert_equal 'G', LucaSupport::Code.encode_month(7)
    assert_equal 'H', LucaSupport::Code.encode_month(8)
    assert_equal 'I', LucaSupport::Code.encode_month(9)
    assert_equal 'J', LucaSupport::Code.encode_month(10)
    assert_equal 'K', LucaSupport::Code.encode_month(11)
    assert_equal 'L', LucaSupport::Code.encode_month(12)
    assert_raises { |_| LucaSupport::Code.encode_month(0) }
    assert_raises { |_| LucaSupport::Code.encode_month(13) }
    assert_equal '', LucaSupport::Code.encode_month(nil)
  end

  def test_decode_month
    assert_equal 1, LucaSupport::Code.decode_month('A')
    assert_equal 12, LucaSupport::Code.decode_month('L')
    assert_nil LucaSupport::Code.decode_month('M')
  end

  def test_decode_term
    assert_equal [2000, 1], LucaSupport::Code.decode_term('2000A')
    assert_equal [9999, 12], LucaSupport::Code.decode_term('9999L')
  end

  def test_delimit_num
    assert_equal '1,000,000', LucaSupport::Code.delimit_num(1_000_000)
    assert_equal '1,000,000', LucaSupport::Code.delimit_num('1000000')
  end

  def test_issue_random_id
    assert_instance_of String, LucaSupport::Code.issue_random_id
    assert_equal 40, LucaSupport::Code.issue_random_id.length
    assert LucaSupport::Code.issue_random_id != LucaSupport::Code.issue_random_id
  end
end
