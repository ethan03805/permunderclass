class User < ApplicationRecord
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

  has_secure_password

  enum :role, { member: 0, moderator: 1, admin: 2 }, default: :member, validate: true
  enum :state, {
    pending_email_verification: 0,
    active: 1,
    suspended: 2,
    banned: 3
  }, default: :pending_email_verification, validate: true

  before_validation :normalize_identifiers

  validates :email,
    presence: true,
    format: { with: URI::MailTo::EMAIL_REGEXP },
    uniqueness: { case_sensitive: false }
  validates :password, presence: true, length: { minimum: 8 }, if: :changing_password?
  validates :pseudonym,
    presence: true,
    format: { with: PSEUDONYM_FORMAT },
    length: { minimum: 3, maximum: 30 },
    uniqueness: { case_sensitive: false }
  validates :reply_alerts_enabled, inclusion: { in: [ true, false ] }
  validate :email_domain_must_not_be_disposable

  generates_token_for :email_verification, expires_in: 7.days do
    email_verified_at&.to_i || 0
  end

  generates_token_for :password_reset, expires_in: 30.minutes do
    password_digest&.last(10)
  end

  def email_verified?
    email_verified_at.present?
  end

  def password_reset_permitted?
    active? || pending_email_verification?
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

  def changing_password?
    new_record? || !password.nil?
  end

  def email_domain_must_not_be_disposable
    return if email.blank? || !DisposableEmailBlocklist.include?(email)

    errors.add(:email, :disposable)
  end
end
