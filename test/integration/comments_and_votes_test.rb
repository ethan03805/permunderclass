require "test_helper"

class CommentsAndVotesTest < ActionDispatch::IntegrationTest
  test "verified users can add a top-level comment" do
    sign_in_as(users(:active_member))
    post_record = posts(:discussion_post)

    assert_difference -> { post_record.comments.count }, 1 do
      post post_comments_path(post_record), params: {
        comment: { body: "A plain, specific comment." },
        comment_sort: "top"
      }
    end

    created_comment = Comment.order(:id).last

    assert_redirected_to post_path(post_record, comment_sort: "top", anchor: "comment-#{created_comment.id}")
    assert_equal 0, created_comment.depth
    assert_equal 1, post_record.reload.comment_count
  end

  test "verified users can reply to an existing comment" do
    sign_in_as(users(:another_active))
    post_record = posts(:commented_post)
    parent_comment = comments(:reply_comment)

    assert_difference -> { parent_comment.reload.reply_count }, 1 do
      post post_comments_path(post_record), params: {
        comment: {
          body: "Following up with one more detail.",
          parent_id: parent_comment.id
        },
        comment_sort: "top"
      }
    end

    created_comment = Comment.order(:id).last

    assert_equal parent_comment.id, created_comment.parent_id
    assert_equal 2, created_comment.depth
  end

  test "removed comments render a tombstone and preserve the thread" do
    comments(:top_comment).update!(status: :removed)

    get post_path(posts(:commented_post))

    assert_response :success
    assert_select ".comment--removed .comment__tombstone", I18n.t("comments.tombstone.body")
    assert_select ".comment-thread--nested .comment", minimum: 1
  end

  test "post votes toggle between create, remove, and opposite direction" do
    sign_in_as(users(:active_member))
    post_record = posts(:discussion_post)

    assert_difference -> { PostVote.count }, 1 do
      post post_vote_path(post_record), params: { value: 1, return_to: post_path(post_record) }
    end

    assert_equal 1, post_record.reload.upvote_count
    assert_equal 1, post_record.score

    assert_difference -> { PostVote.count }, -1 do
      post post_vote_path(post_record), params: { value: 1, return_to: post_path(post_record) }
    end

    assert_equal 0, post_record.reload.upvote_count
    assert_equal 0, post_record.score

    assert_difference -> { PostVote.count }, 1 do
      post post_vote_path(post_record), params: { value: -1, return_to: post_path(post_record) }
    end

    assert_equal 1, post_record.reload.downvote_count
    assert_equal(-1, post_record.score)
  end

  test "comment votes update counts and top sorting" do
    sign_in_as(users(:active_member))
    post_record = posts(:discussion_post)
    first_comment = Comment.create!(post: post_record, user: users(:moderator), body: "First root comment")
    second_comment = Comment.create!(post: post_record, user: users(:another_active), body: "Second root comment")

    second_comment.comment_votes.create!(user: users(:moderator), value: 1)

    post comment_vote_path(second_comment), params: {
      value: 1,
      return_to: post_path(post_record, comment_sort: "top")
    }

    second_comment.reload
    assert_equal 2, second_comment.upvote_count
    assert_equal 2, second_comment.score

    get post_path(post_record, comment_sort: "top")

    assert_response :success
    assert_select "ol.comment-thread > li:first-child", text: /Second root comment/
    assert_select ".comment .vote-box__summary", text: /2 upvotes/
  end
end
