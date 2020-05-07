require 'minitest/autorun'
require 'date'
require_relative '../code'

class Luca::CodeTest < Minitest::Test
  include Luca::Code

  def test_encode_txid
    assert_equal "000", encode_txid(0)
  end

  def test_decode_txid
    assert_equal 0, decode_txid("000")
  end

  def test_encode_month
    assert_equal "A", encode_month(1)
    assert_equal "A", encode_month("1")
    assert_equal "A", encode_month(Date.parse("2020-1-1"))
    assert_equal "A", encode_month(DateTime.parse("2020-01-07T19:02:02+09:00"))
    assert_equal "B", encode_month(2)
    assert_equal "B", encode_month(Date.parse("2020-2-1"))
    assert_equal "C", encode_month(3)
    assert_equal "D", encode_month(4)
    assert_equal "E", encode_month(5)
    assert_equal "F", encode_month(6)
    assert_equal "G", encode_month(7)
    assert_equal "H", encode_month(8)
    assert_equal "I", encode_month(9)
    assert_equal "J", encode_month(10)
    assert_equal "K", encode_month(11)
    assert_equal "L", encode_month(12)
  end

  def test_decode_month
    assert_equal 1, decode_month("A")
    assert_equal 2, decode_month("B")
    assert_equal 3, decode_month("C")
    assert_equal 4, decode_month("D")
    assert_equal 5, decode_month("E")
    assert_equal 6, decode_month("F")
    assert_equal 7, decode_month("G")
    assert_equal 8, decode_month("H")
    assert_equal 9, decode_month("I")
    assert_equal 10, decode_month("J")
    assert_equal 11, decode_month("K")
    assert_equal 12, decode_month("L")
  end

  def test_encode_date
    assert_equal "1", encode_date(1)
    assert_equal "1", encode_date(Date.parse("2020-1-1"))
    assert_equal "1", encode_date(DateTime.parse("2020-07-01T19:02:02+09:00"))
    assert_equal "v", encode_date(31)
  end

  def test_decode_date
    assert_equal 1, decode_date("1")
    assert_equal 31, decode_date("v")
  end

  def test_issue_random_id
    assert_instance_of String, issue_random_id
    assert_equal 40, issue_random_id.length
    assert_operator issue_random_id, :!=, issue_random_id
  end
end
