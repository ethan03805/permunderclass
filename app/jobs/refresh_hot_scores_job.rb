class RefreshHotScoresJob < ApplicationJob
  queue_as :default

  def perform
    Post.feed_recent.find_each do |post|
      new_score = PostRanking.compute(score: post.score, published_at: post.published_at)
      post.update_column(:hot_score, new_score) unless post.hot_score == new_score
    end
  end
end
