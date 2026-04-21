require "test_helper"

class PostVoteTest < ActiveSupport::TestCase
  test "fixture post vote is valid" do
    assert post_votes(:post_vote_up).valid?
  end

  test "value must be 1 or -1" do
    vote = PostVote.new(user: users(:active_member), post: posts(:discussion_post), value: 0)
    assert_not vote.valid?
    assert_includes vote.errors[:value], I18n.t("activerecord.errors.models.post_vote.attributes.value.inclusion")
  end

  test "one vote per user per post" do
    existing = post_votes(:post_vote_up)
    vote = PostVote.new(user: existing.user, post: existing.post, value: -1)
    assert_not vote.valid?
    assert_includes vote.errors[:user_id], I18n.t("activerecord.errors.models.post_vote.attributes.user_id.taken")
  end

  test "creating a vote refreshes post counters" do
    post = posts(:discussion_post)
    original_score = post.score
    PostVote.create!(user: users(:active_member), post: post, value: 1)
    post.reload
    assert_equal original_score + 1, post.score
    assert_equal 1, post.upvote_count
  end

  test "updating a vote refreshes post counters" do
    vote = post_votes(:post_vote_up)
    post = vote.post
    original_score = post.score
    vote.update!(value: -1)
    post.reload
    assert_equal original_score - 2, post.score
    assert_equal 0, post.upvote_count
    assert_equal 1, post.downvote_count
  end

  test "destroying a vote refreshes post counters" do
    vote = post_votes(:post_vote_up)
    post = vote.post
    original_score = post.score
    vote.destroy!
    post.reload
    assert_equal original_score - 1, post.score
    assert_equal 0, post.upvote_count
  end
end
