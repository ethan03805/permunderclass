require "test_helper"

class CommentThreadQueryTest < ActiveSupport::TestCase
  test "default sort is top" do
    query = CommentThreadQuery.new(post: posts(:commented_post))

    assert_equal "top", query.sort
  end

  test "invalid sort falls back to top" do
    query = CommentThreadQuery.new(post: posts(:commented_post), sort: "invalid")

    assert_equal "top", query.sort
  end

  test "top sort orders sibling comments by score descending" do
    post = posts(:discussion_post)
    lower = Comment.create!(post: post, user: users(:active_member), body: "Lower score")
    higher = Comment.create!(post: post, user: users(:another_active), body: "Higher score")

    lower.update_columns(score: 1, upvote_count: 1)
    higher.update_columns(score: 3, upvote_count: 3)

    result = CommentThreadQuery.new(post: post, sort: "top").call

    assert_equal [ higher.id, lower.id ], result[:comments_by_parent][nil].map(&:id)
  end

  test "new sort orders sibling comments by newest first" do
    post = posts(:discussion_post)
    older = Comment.create!(post: post, user: users(:active_member), body: "Older")
    newer = Comment.create!(post: post, user: users(:another_active), body: "Newer")

    older.update_columns(created_at: 2.hours.ago, updated_at: 2.hours.ago)
    newer.update_columns(created_at: 1.hour.ago, updated_at: 1.hour.ago)

    result = CommentThreadQuery.new(post: post, sort: "new").call

    assert_equal [ newer.id, older.id ], result[:comments_by_parent][nil].map(&:id)
  end

  test "controversial sort prioritizes eligible comments by controversy score" do
    post = posts(:discussion_post)
    most_controversial = Comment.create!(post: post, user: users(:active_member), body: "Most controversial")
    less_controversial = Comment.create!(post: post, user: users(:another_active), body: "Less controversial")
    ineligible = Comment.create!(post: post, user: users(:moderator), body: "Not enough votes")

    most_controversial.update_columns(upvote_count: 3, downvote_count: 3, score: 0, created_at: 3.hours.ago, updated_at: 3.hours.ago)
    less_controversial.update_columns(upvote_count: 5, downvote_count: 1, score: 4, created_at: 2.hours.ago, updated_at: 2.hours.ago)
    ineligible.update_columns(upvote_count: 2, downvote_count: 0, score: 2, created_at: 1.hour.ago, updated_at: 1.hour.ago)

    result = CommentThreadQuery.new(post: post, sort: "controversial").call

    assert_equal [ most_controversial.id, less_controversial.id, ineligible.id ], result[:comments_by_parent][nil].map(&:id)
  end
end
