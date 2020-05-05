module LucaSupport

  def self.match_score(a, b, n=2)
    v_a = to_ngram(a, n)
    v_b = to_ngram(b, n)

    v_a.map{|item| v_b.include?(item) ? 1 : 0 }.sum / v_a.length.to_f
  end

  def self.to_ngram(str, n=2)
    str.each_char.each_cons(n)
      .map(&:join)
  end

end
