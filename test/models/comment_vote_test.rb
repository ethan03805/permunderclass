require "test_helper"

class CommentVoteTest < ActiveSupport::TestCase
  test "fixture comment vote is valid" do
    assert comment_votes(:comment_vote_up).valid?
  end

  test "value must be 1 or -1" do
    vote = CommentVote.new(user: users(:active_member), comment: comments(:top_comment), value: 0)
    assert_not vote.valid?
    assert_includes vote.errors[:value], I18n.t("activerecord.errors.models.comment_vote.attributes.value.inclusion")
  end

  test "one vote per user per comment" do
    existing = comment_votes(:comment_vote_up)
    vote = CommentVote.new(user: existing.user, comment: existing.comment, value: -1)
    assert_not vote.valid?
    assert_includes vote.errors[:user_id], I18n.t("activerecord.errors.models.comment_vote.attributes.user_id.taken")
  end

  test "creating a vote refreshes comment counters" do
    comment = comments(:top_comment)
    original_score = comment.score
    CommentVote.create!(user: users(:active_member), comment: comment, value: 1)
    comment.reload
    assert_equal original_score + 1, comment.score
    assert_equal 2, comment.upvote_count
  end

  test "updating a vote refreshes comment counters" do
    vote = comment_votes(:comment_vote_up)
    comment = vote.comment
    original_score = comment.score
    vote.update!(value: -1)
    comment.reload
    assert_equal original_score - 2, comment.score
    assert_equal 0, comment.upvote_count
    assert_equal 1, comment.downvote_count
  end

  test "destroying a vote refreshes comment counters" do
    vote = comment_votes(:comment_vote_up)
    comment = vote.comment
    original_score = comment.score
    vote.destroy!
    comment.reload
    assert_equal original_score - 1, comment.score
    assert_equal 0, comment.upvote_count
  end
end
