class PostRanking
  def self.compute(score:, published_at:)
    return 0.0 unless published_at

    order = Math.log10([ score.abs, 1 ].max)
    sign = score <=> 0
    seconds = published_at.to_i - Post::HOT_SCORE_EPOCH
    (sign * order + seconds / 64_800.0).round(7)
  end
end
