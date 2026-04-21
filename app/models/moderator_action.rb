class ModeratorAction < ApplicationRecord
  TARGET_TYPES = %w[Post Comment User Tag Report].freeze
  ACTION_TARGET_TYPES = {
    rewrite_requested: [ "Post" ],
    restored: [ "Post" ],
    removed: [ "Post" ],
    comment_removed: [ "Comment" ],
    user_suspended: [ "User" ],
    user_banned: [ "User" ],
    tag_created: [ "Tag" ],
    tag_renamed: [ "Tag" ],
    tag_merged: [ "Tag" ],
    tag_archived: [ "Tag" ],
    report_dismissed: [ "Report" ]
  }.freeze

  belongs_to :moderator, class_name: "User"
  belongs_to :target, polymorphic: true

  enum :action_type, {
    rewrite_requested: 0,
    restored: 1,
    removed: 2,
    comment_removed: 3,
    user_suspended: 4,
    user_banned: 5,
    tag_created: 6,
    tag_renamed: 7,
    tag_merged: 8,
    tag_archived: 9,
    report_dismissed: 10
  }, validate: true

  validates :public_note, presence: true
  validates :internal_note, presence: true
  validate :moderator_can_moderate
  validate :target_type_allowed
  validate :action_type_matches_target_type

  private

  def moderator_can_moderate
    return if moderator&.moderator? || moderator&.admin?

    errors.add(:moderator, :invalid_role)
  end

  def target_type_allowed
    return if target_type.in?(TARGET_TYPES)

    errors.add(:target_type, :inclusion)
  end

  def action_type_matches_target_type
    return if action_type.blank? || target_type.blank?
    return if target_type.in?(ACTION_TARGET_TYPES.fetch(action_type.to_sym, []))

    errors.add(:target_type, :invalid_for_action)
  end
end
