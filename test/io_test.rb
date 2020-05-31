require_relative 'test_helper'
require 'date'
require 'luca/io'

class Luca::IOTest < Minitest::Test
  include Luca::IO

  def test_encode_dirname
    assert_equal "2020B", encode_dirname(Date.parse("2020-2-1"))
    assert_equal "9999L", encode_dirname(Date.parse("9999-12-31"))
  end
end
