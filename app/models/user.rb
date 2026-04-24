class User < ApplicationRecord
  FRESH_ACCOUNT_WINDOW = 24.hours
  PSEUDONYM_FORMAT = /\A[a-z0-9_]+\z/i

  has_many :posts, dependent: :restrict_with_error
  has_many :comments, dependent: :restrict_with_error
  has_many :reports, as: :target, dependent: :restrict_with_error
  has_many :post_votes, dependent: :destroy
  has_many :comment_votes, dependent: :destroy
  has_many :reports_as_reporter, class_name: "Report", foreign_key: :reporter_id, dependent: :restrict_with_error
  has_many :reports_resolved, class_name: "Report", foreign_key: :resolved_by_id, dependent: :restrict_with_error
  has_many :moderator_actions, foreign_key: :moderator_id, dependent: :restrict_with_error
  has_many :targeted_moderator_actions, as: :target, class_name: "ModeratorAction", dependent: :restrict_with_error

  encrypts :totp_secret
  encrypts :totp_candidate_secret

  enum :role, { member: 0, moderator: 1, admin: 2 }, default: :member, validate: true
  enum :state, {
    pending_enrollment: 0,
    active: 1,
    suspended: 2,
    banned: 3
  }, default: :pending_enrollment, validate: true

  before_validation :normalize_identifiers

  validates :email,
    presence: true,
    format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: { case_sensitive: false }
  validates :pseudonym,
    presence: true,
    format: { with: PSEUDONYM_FORMAT },
    length: { minimum: 3, maximum: 30 },
    uniqueness: { case_sensitive: false }
  validates :reply_alerts_enabled, inclusion: { in: [ true, false ] }
  validate :email_domain_must_not_be_disposable

  def email_verified?
    email_verified_at.present?
  end

  def fresh_account?(reference_time: Time.current)
    active? && email_verified? && email_verified_at >= (reference_time - FRESH_ACCOUNT_WINDOW)
  end

  def verify_email!
    return if email_verified? || suspended? || banned?

    update!(email_verified_at: Time.current, state: :active)
  end

  private

  def normalize_identifiers
    self.email = email.to_s.strip.downcase.presence
    self.pseudonym = pseudonym.to_s.strip.downcase.presence
  end

  def email_domain_must_not_be_disposable
    return if email.blank? || !DisposableEmailBlocklist.include?(email)

    errors.add(:email, :disposable)
  end
end
