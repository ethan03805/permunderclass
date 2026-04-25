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

  ENROLLMENT_TOKEN_TTL = 30.minutes

  generates_token_for :enrollment, expires_in: ENROLLMENT_TOKEN_TTL do
    [ email_verified_at&.to_i || 0, enrollment_token_generation ]
  end

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

  def totp
    return if totp_secret.blank?

    @totp ||= ROTP::TOTP.new(totp_secret, issuer: Rails.configuration.x.totp_issuer || "permanentunderclass.me")
  end

  def verify_totp(code)
    return false if totp.nil? || code.blank?

    counter = totp.verify(code.to_s, drift_behind: 30, drift_ahead: 30, after: totp_last_used_counter)
    return false if counter.nil?

    update_column(:totp_last_used_counter, counter)
    true
  end

  ENROLLMENT_CANDIDATE_TTL = 30.minutes

  def begin_enrollment!
    now = Time.current
    fresh = totp_candidate_secret.blank? || totp_candidate_secret_expires_at.nil? || totp_candidate_secret_expires_at < now

    return unless fresh

    update!(
      totp_candidate_secret: ROTP::Base32.random,
      totp_candidate_secret_expires_at: now + ENROLLMENT_CANDIDATE_TTL
    )
  end

  def complete_enrollment!
    if totp_candidate_secret.blank?
      errors.add(:base, "No candidate secret")
      raise ActiveRecord::RecordInvalid, self
    end

    updates = {
      totp_secret: totp_candidate_secret,
      totp_candidate_secret: nil,
      totp_candidate_secret_expires_at: nil,
      totp_last_used_counter: nil
    }

    if pending_enrollment?
      updates[:state] = :active
      updates[:email_verified_at] = Time.current
    else
      updates[:sessions_generation] = sessions_generation + 1
      updates[:enrollment_token_generation] = enrollment_token_generation + 1
    end

    update!(updates)
    @totp = nil
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
