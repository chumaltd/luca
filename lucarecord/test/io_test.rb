# frozen_string_literal: true

require_relative 'test_helper'
require 'date'

class LucaRecord::IOTest < Minitest::Test
  include LucaRecord::IO

  def test_encode_dirname
    assert_equal '2020B', self.class.encode_dirname(Date.parse('2020-2-1'))
    assert_equal '9999L', self.class.encode_dirname(Date.parse('9999-12-31'))
  end

  def test_id2path
    assert_equal '2020H/V001-a7b806d04a044c6dbc4ce72932867719', self.class.id2path(['2020H', 'V001', 'a7b806d04a044c6dbc4ce72932867719'])
    assert_equal 'a7b/806d04a044c6dbc4ce72932867719', self.class.id2path('a7b806d04a044c6dbc4ce72932867719')
    assert_equal '2020H/V001', self.class.id2path('2020H/V001')
  end

end
