require "test_helper"

class ModeratorActionTest < ActiveSupport::TestCase
  test "fixture moderator action is valid" do
    assert moderator_actions(:request_rewrite_action).valid?
  end

  test "action_type must be valid" do
    action = ModeratorAction.new(
      moderator: users(:moderator),
      target: posts(:commented_post),
      action_type: :invalid_type,
      public_note: "Public note",
      internal_note: "Internal note"
    )
    assert_not action.valid?
  end

  test "target can be Post" do
    action = ModeratorAction.new(
      moderator: users(:moderator),
      target: posts(:commented_post),
      action_type: :removed,
      public_note: "Public note",
      internal_note: "Internal note"
    )
    assert action.valid?
  end

  test "target can be Comment" do
    action = ModeratorAction.new(
      moderator: users(:moderator),
      target: comments(:top_comment),
      action_type: :comment_removed,
      public_note: "Public note",
      internal_note: "Internal note"
    )
    assert action.valid?
  end

  test "target can be User" do
    action = ModeratorAction.new(
      moderator: users(:moderator),
      target: users(:active_member),
      action_type: :user_suspended,
      public_note: "Public note",
      internal_note: "Internal note"
    )
    assert action.valid?
  end

  test "target can be Tag" do
    action = ModeratorAction.new(
      moderator: users(:moderator),
      target: tags(:active_tag),
      action_type: :tag_archived,
      public_note: "Public note",
      internal_note: "Internal note"
    )
    assert action.valid?
  end

  test "target can be Report" do
    action = ModeratorAction.new(
      moderator: users(:moderator),
      target: reports(:open_post_report),
      action_type: :report_dismissed,
      public_note: "Public note",
      internal_note: "Internal note"
    )
    assert action.valid?
  end

  test "public_note and internal_note are required" do
    action = ModeratorAction.new(
      moderator: users(:moderator),
      target: posts(:commented_post),
      action_type: :removed,
      public_note: "",
      internal_note: ""
    )

    assert_not action.valid?
    assert_includes action.errors[:public_note], I18n.t("activerecord.errors.models.moderator_action.attributes.public_note.blank")
    assert_includes action.errors[:internal_note], I18n.t("activerecord.errors.models.moderator_action.attributes.internal_note.blank")
  end

  test "moderator must have a moderation role" do
    action = ModeratorAction.new(
      moderator: users(:active_member),
      target: posts(:commented_post),
      action_type: :removed,
      public_note: "Public note",
      internal_note: "Internal note"
    )

    assert_not action.valid?
    assert_includes action.errors[:moderator], I18n.t("activerecord.errors.models.moderator_action.attributes.moderator.invalid_role")
  end

  test "admin may perform moderator actions" do
    action = ModeratorAction.new(
      moderator: users(:admin),
      target: posts(:commented_post),
      action_type: :removed,
      public_note: "Public note",
      internal_note: "Internal note"
    )

    assert action.valid?
  end

  test "action type must match target type" do
    action = ModeratorAction.new(
      moderator: users(:moderator),
      target: users(:active_member),
      action_type: :comment_removed,
      public_note: "Public note",
      internal_note: "Internal note"
    )

    assert_not action.valid?
    assert_includes action.errors[:target_type], I18n.t("activerecord.errors.models.moderator_action.attributes.target_type.invalid_for_action")
  end
end
