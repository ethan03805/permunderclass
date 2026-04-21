require "test_helper"

class PostDetailTest < ActionDispatch::IntegrationTest
  test "published posts are visible on the detail route" do
    get post_path(posts(:commented_post))

    assert_response :success
    assert_select "h1", posts(:commented_post).title
  end

  test "rewrite requested posts remain visible on their direct route" do
    get post_path(posts(:rewrite_requested_post))

    assert_response :success
    assert_select ".rewrite-banner", text: /#{Regexp.escape(posts(:rewrite_requested_post).rewrite_reason)}/
  end

  test "removed posts return not found for anonymous visitors" do
    get post_path(posts(:removed_post))

    assert_response :not_found
  end

  test "removed posts return not found for regular members" do
    sign_in_as(users(:active_member))

    get post_path(posts(:removed_post))

    assert_response :not_found
  end

  test "removed posts remain visible to moderators" do
    sign_in_as(users(:moderator))

    get post_path(posts(:removed_post))

    assert_response :success
    assert_select ".rewrite-banner", text: /#{Regexp.escape(I18n.t("posts.detail.statuses.removed.title"))}/
  end

  test "authors can edit their own rewrite requested posts and republish them" do
    sign_in_as(users(:active_member))

    get edit_post_path(posts(:rewrite_requested_post))
    assert_response :success

    patch post_path(posts(:rewrite_requested_post)), params: {
      post: {
        title: "Needs rewrite but fixed",
        body: "The revised version is much plainer.",
        tag_ids: [ tags(:active_tag).id ]
      }
    }

    updated_post = posts(:rewrite_requested_post).reload

    assert_redirected_to post_path(updated_post)
    assert_equal "published", updated_post.status
    assert_nil updated_post.rewrite_reason
  end

  test "non-authors cannot edit posts" do
    sign_in_as(users(:another_active))

    get edit_post_path(posts(:rewrite_requested_post))

    assert_response :not_found
  end
end
