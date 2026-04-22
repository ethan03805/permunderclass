require "test_helper"

class ModerationAndReportingTest < ActionDispatch::IntegrationTest
  test "verified users can report a post" do
    sign_in_as(users(:active_member))

    assert_difference("Report.count", 1) do
      post reports_path, params: {
        target_type: "Post",
        target_id: posts(:discussion_post).id,
        return_to: post_path(posts(:discussion_post)),
        anchor: "post-#{posts(:discussion_post).id}",
        report: {
          reason_code: "spam",
          details: "This needs review."
        }
      }
    end

    report = Report.order(:id).last

    assert_redirected_to post_path(posts(:discussion_post), anchor: "post-#{posts(:discussion_post).id}")
    assert_equal users(:active_member), report.reporter
    assert_equal posts(:discussion_post), report.target
    assert_equal "open", report.status
  end

  test "non moderators cannot access moderation routes" do
    sign_in_as(users(:active_member))

    get mod_reports_path

    assert_redirected_to root_path
    follow_redirect!
    assert_select ".flash", I18n.t("auth.guards.moderation_required")
  end

  test "moderators can request a rewrite from the reports queue" do
    sign_in_as(users(:moderator))
    report = Report.create!(reporter: users(:active_member), target: posts(:discussion_post), reason_code: :hype, status: :open)

    patch mod_report_path(report), params: {
      moderation: {
        decision: "rewrite_requested",
        public_note: "Please rewrite this with more detail.",
        internal_note: "Reads more like hype than a concrete update."
      }
    }

    assert_redirected_to mod_report_path(report)
    assert_equal "resolved", report.reload.status
    assert_equal "rewrite_requested", posts(:discussion_post).reload.status
    assert_equal "Please rewrite this with more detail.", posts(:discussion_post).rewrite_reason
    assert_equal "rewrite_requested", ModeratorAction.order(:id).last.action_type
  end

  test "moderators can restore a removed post from the post detail surface" do
    sign_in_as(users(:moderator))

    patch moderate_mod_post_path(posts(:removed_post)), params: {
      moderation: {
        action_type: "restored",
        public_note: "Restoring after review.",
        internal_note: "Removal was too broad."
      }
    }

    assert_redirected_to post_path(posts(:removed_post))
    assert_equal "published", posts(:removed_post).reload.status
    assert_nil posts(:removed_post).rewrite_reason
    assert_equal "restored", ModeratorAction.order(:id).last.action_type
  end

  test "moderators can remove comments and the thread keeps the tombstone" do
    sign_in_as(users(:moderator))

    patch moderate_mod_comment_path(comments(:top_comment)), params: {
      moderation: {
        public_note: "Removing this comment.",
        internal_note: "Clear violation."
      }
    }

    assert_redirected_to post_path(posts(:commented_post), anchor: "comment-#{comments(:top_comment).id}")
    assert_equal "removed", comments(:top_comment).reload.status

    get post_path(posts(:commented_post))

    assert_response :success
    assert_select ".comment--removed .comment__tombstone", I18n.t("comments.tombstone.body")
    assert_equal "comment_removed", ModeratorAction.order(:id).last.action_type
  end

  test "moderators can suspend users from the account review screen" do
    sign_in_as(users(:moderator))

    patch moderate_mod_user_path(users(:another_active)), params: {
      moderation: {
        action_type: "user_suspended",
        public_note: "Suspending this account.",
        internal_note: "Pattern of repeated abuse reports."
      }
    }

    assert_redirected_to mod_user_path(users(:another_active))
    assert_equal "suspended", users(:another_active).reload.state
    assert_equal "user_suspended", ModeratorAction.order(:id).last.action_type
  end

  test "moderators can create rename merge and archive tags" do
    sign_in_as(users(:moderator))

    post mod_tags_path, params: {
      tag: { name: "launches" },
      moderation: {
        public_note: "Creating a new tag.",
        internal_note: "Needed for current queue."
      }
    }

    created_tag = Tag.order(:id).last
    assert_equal "launches", created_tag.name

    patch mod_tag_path(created_tag), params: {
      tag_action: "rename",
      tag: { name: "launch-updates" },
      moderation: {
        public_note: "Renaming for clarity.",
        internal_note: "Better matches site copy."
      }
    }

    assert_equal "launch-updates", created_tag.reload.name

    source_tag = Tag.create!(name: "old-source")
    target_tag = Tag.create!(name: "new-target")
    PostTag.create!(post: posts(:discussion_post), tag: source_tag)

    patch merge_mod_tags_path, params: {
      source_tag_id: source_tag.id,
      target_tag_id: target_tag.id,
      moderation: {
        public_note: "Merging duplicate tags.",
        internal_note: "Consolidating vocabulary."
      }
    }

    assert source_tag.reload.archived?
    assert_includes posts(:discussion_post).tags.reload, target_tag
    assert_not_includes posts(:discussion_post).tags.reload, source_tag

    patch mod_tag_path(created_tag), params: {
      tag_action: "archive",
      moderation: {
        public_note: "Archiving unused tag.",
        internal_note: "No active usage."
      }
    }

    assert created_tag.reload.archived?
    assert_includes ModeratorAction.order(:created_at).last(4).map(&:action_type), "tag_archived"
  end
end
