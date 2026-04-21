class Report < ApplicationRecord
  TARGET_TYPES = %w[Post Comment User].freeze

  belongs_to :reporter, class_name: "User"
  belongs_to :resolved_by, class_name: "User", optional: true
  belongs_to :target, polymorphic: true

  has_many :moderator_actions, as: :target, dependent: :restrict_with_error

  enum :reason_code, { spam: 0, hype: 1, abuse: 2, off_topic: 3, other: 4 }, validate: true
  enum :status, { open: 0, resolved: 1, dismissed: 2 }, default: :open, validate: true

  validates :details, length: { maximum: 5000 }, allow_blank: true
  validates :reporter_id, uniqueness: { scope: [ :target_type, :target_id ], conditions: -> { where(status: :open) } }
  before_validation :clear_resolved_fields, if: :open?
  validate :resolved_fields_present_when_closed
  validate :resolved_by_must_have_moderation_role
  validate :target_type_allowed

  before_destroy :capture_destroyed_target_identity
  after_save :refresh_affected_target_report_counts
  after_destroy :refresh_destroyed_target_report_count

  private

  def resolved_fields_present_when_closed
    return if open?

    errors.add(:resolved_by_id, :blank) if resolved_by_id.blank?
    errors.add(:resolved_at, :blank) if resolved_at.blank?
  end

  def resolved_by_must_have_moderation_role
    return if open? || resolved_by.blank? || resolved_by.moderator? || resolved_by.admin?

    errors.add(:resolved_by, :invalid_role)
  end

  def target_type_allowed
    return if target_type.in?(TARGET_TYPES)

    errors.add(:target_type, :inclusion)
  end

  def clear_resolved_fields
    self.resolved_by = nil
    self.resolved_at = nil
  end

  def capture_destroyed_target_identity
    @destroyed_target_type = target_type
    @destroyed_target_id = target_id
  end

  def refresh_affected_target_report_counts
    refresh_target_report_count(target)

    previous_target_type = saved_change_to_target_type&.first
    previous_target_id = saved_change_to_target_id&.first
    return if previous_target_type.blank? || previous_target_id.blank?

    refresh_target_report_count_for(previous_target_type, previous_target_id)
  end

  def refresh_destroyed_target_report_count
    refresh_target_report_count_for(@destroyed_target_type, @destroyed_target_id)
  end

  def refresh_target_report_count(record)
    record.refresh_report_count! if record.respond_to?(:refresh_report_count!)
  end

  def refresh_target_report_count_for(target_type_name, target_id_value)
    return if target_type_name.blank? || target_id_value.blank?

    {
      "Post" => Post,
      "Comment" => Comment,
      "User" => User
    }[target_type_name]&.find_by(id: target_id_value)&.then do |record|
      refresh_target_report_count(record)
    end
  end
end
