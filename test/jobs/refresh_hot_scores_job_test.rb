require "test_helper"

class RefreshHotScoresJobTest < ActiveSupport::TestCase
  test "refreshes hot_score for recent posts" do
    post = Post.create!(user: users(:active_member), post_type: :discussion, title: "Recent", body: "Body")
    post.update_columns(published_at: 1.day.ago, score: 5, hot_score: 0.0)

    RefreshHotScoresJob.perform_now

    post.reload
    expected = PostRanking.compute(score: 5, published_at: post.published_at)
    assert_equal expected, post.hot_score
  end

  test "does not refresh hot_score for old posts" do
    post = Post.create!(user: users(:active_member), post_type: :discussion, title: "Old", body: "Body")
    post.update_columns(published_at: 15.days.ago, score: 5, hot_score: 0.0)

    RefreshHotScoresJob.perform_now

    post.reload
    assert_equal 0.0, post.hot_score
  end
end
