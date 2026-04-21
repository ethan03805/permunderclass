require "test_helper"

class PostRankingTest < ActiveSupport::TestCase
  test "compute returns 0.0 when published_at is missing" do
    assert_equal 0.0, PostRanking.compute(score: 10, published_at: nil)
  end

  test "compute matches manual hot ranking formula" do
    published_at = Time.at(Post::HOT_SCORE_EPOCH)
    expected = 1.0
    assert_equal expected, PostRanking.compute(score: 10, published_at: published_at)
  end

  test "compute handles negative scores" do
    published_at = Time.at(Post::HOT_SCORE_EPOCH)
    expected = -1.0
    assert_equal expected, PostRanking.compute(score: -10, published_at: published_at)
  end

  test "compute handles zero score" do
    published_at = Time.at(Post::HOT_SCORE_EPOCH)
    expected = 0.0
    assert_equal expected, PostRanking.compute(score: 0, published_at: published_at)
  end

  test "compute delegates through Post.compute_hot_score" do
    published_at = Time.at(Post::HOT_SCORE_EPOCH)
    assert_equal PostRanking.compute(score: 5, published_at: published_at),
                 Post.compute_hot_score(score: 5, published_at: published_at)
  end
end
