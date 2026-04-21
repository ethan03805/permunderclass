require "test_helper"

class CommentTest < ActiveSupport::TestCase
  test "fixture comments are valid" do
    assert comments(:top_comment).valid?
    assert comments(:reply_comment).valid?
  end

  test "body is required and limited to 5000 characters" do
    comment = comments(:top_comment)
    comment.body = ""
    assert_not comment.valid?
    assert_includes comment.errors[:body], I18n.t("activerecord.errors.models.comment.attributes.body.blank")

    comment.body = "a" * 5001
    assert_not comment.valid?
    assert_includes comment.errors[:body], I18n.t("activerecord.errors.models.comment.attributes.body.too_long", count: 5000)
  end

  test "depth is limited to 8" do
    parent = comments(:reply_comment)
    parent.update_column(:depth, 8)
    comment = Comment.new(post: parent.post, user: users(:another_active), parent: parent, body: "Too deep")

    assert_not comment.valid?
    assert_includes comment.errors[:depth], I18n.t("activerecord.errors.models.comment.attributes.depth.less_than_or_equal_to", count: 8)
  end

  test "depth is computed from parent on create" do
    parent = comments(:reply_comment)
    child = Comment.create!(post: parent.post, user: users(:another_active), parent: parent, body: "Nested reply")
    assert_equal parent.depth + 1, child.depth
  end

  test "top level comment has depth 0" do
    comment = Comment.create!(post: posts(:discussion_post), user: users(:another_active), body: "Top level")
    assert_equal 0, comment.depth
  end

  test "reply parent must belong to the same post" do
    comment = Comment.new(
      post: posts(:discussion_post),
      user: users(:another_active),
      parent: comments(:top_comment),
      body: "Wrong tree"
    )

    assert_not comment.valid?
    assert_includes comment.errors[:parent], I18n.t("activerecord.errors.models.comment.attributes.parent.invalid_post")
  end

  test "comment cannot reference itself as parent" do
    comment = comments(:top_comment)
    comment.parent_id = comment.id

    assert_not comment.valid?
    assert_includes comment.errors[:parent], I18n.t("activerecord.errors.models.comment.attributes.parent.self_reference")
  end

  test "comment cannot reference one of its descendants as parent" do
    parent = comments(:top_comment)
    child = comments(:reply_comment)

    parent.parent = child

    assert_not parent.valid?
    assert_includes parent.errors[:parent], I18n.t("activerecord.errors.models.comment.attributes.parent.descendant")
  end

  test "creating a reply increments parent reply_count" do
    parent = comments(:top_comment)
    original = parent.reply_count
    Comment.create!(post: parent.post, user: users(:another_active), parent: parent, body: "Reply")
    assert_equal original + 1, parent.reload.reply_count
  end

  test "creating a comment increments post comment_count" do
    post = posts(:discussion_post)
    original = post.comment_count

    Comment.create!(post: post, user: users(:another_active), body: "Reply")

    assert_equal original + 1, post.reload.comment_count
  end

  test "destroying a reply decrements parent reply_count" do
    parent = comments(:top_comment)
    reply = Comment.create!(post: parent.post, user: users(:another_active), parent: parent, body: "Reply")
    original = parent.reload.reply_count
    reply.destroy!
    assert_equal original - 1, parent.reload.reply_count
  end

  test "destroying a comment decrements post comment_count" do
    post = posts(:discussion_post)
    comment = Comment.create!(post: post, user: users(:another_active), body: "Reply")
    original = post.reload.comment_count

    comment.destroy!

    assert_equal original - 1, post.reload.comment_count
  end

  test "cannot destroy comment with replies" do
    parent = comments(:top_comment)
    assert_raises(ActiveRecord::RecordNotDestroyed) do
      parent.destroy!
    end
  end

  test "refresh_vote_counters recalculates counts" do
    comment = comments(:top_comment)
    comment.comment_votes.create!(user: users(:active_member), value: 1)

    comment.reload.refresh_vote_counters!
    assert_equal 2, comment.upvote_count
    assert_equal 0, comment.downvote_count
    assert_equal 2, comment.score
  end

  test "edited_at updates on content change" do
    comment = comments(:top_comment)

    comment.update!(body: "Updated body")

    assert comment.edited_at.present?
  end
end
