require_relative 'test_helper'

class LucaSupportTest < Minitest::Test
  def test_match_score_bigram
    assert_equal 1.to_f, LucaSupport.match_score("abcdefgh", "abcdefgh")
    assert_equal 0.to_f, LucaSupport.match_score("abcdefgh", "123c456")
    assert_operator 0.to_f, :<, LucaSupport.match_score("abcdefgh", "123bc456")
    assert_equal 0.to_f, LucaSupport.match_score("abcdefgh", "123456")
  end

  def test_match_score_trigram
    assert_equal 1.to_f, LucaSupport.match_score("abcdefgh", "abcdefgh", 3)
    assert_equal 0.to_f, LucaSupport.match_score("abcdefgh", "123c456", 3)
    assert_equal 0.to_f, LucaSupport.match_score("abcdefgh", "123bc456", 3)
    assert_operator 0.to_f, :<, LucaSupport.match_score("abcdefgh", "12abc456", 3)
    assert_equal 0.to_f, LucaSupport.match_score("abcdefgh", "123456", 3)
  end
end
