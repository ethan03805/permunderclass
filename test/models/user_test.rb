require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "fixture user is valid" do
    assert users(:active_member).valid?
  end

  test "pseudonym format is restricted" do
    user = User.new(
      email: "format@example.com",
      pseudonym: "bad pseudonym"
    )

    assert_not user.valid?
    assert_includes user.errors[:pseudonym], I18n.t("activerecord.errors.models.user.attributes.pseudonym.invalid")
  end

  test "email uniqueness is case insensitive" do
    user = User.new(
      email: "ACTIVE@example.com",
      pseudonym: "another_builder"
    )

    assert_not user.valid?
    assert_includes user.errors[:email], I18n.t("activerecord.errors.models.user.attributes.email.taken")
  end

  test "pseudonym uniqueness is case insensitive" do
    user = User.new(
      email: "other@example.com",
      pseudonym: "ACTIVE_BUILDER"
    )

    assert_not user.valid?
    assert_includes user.errors[:pseudonym], I18n.t("activerecord.errors.models.user.attributes.pseudonym.taken")
  end

  test "verify_email activates pending account" do
    user = users(:pending_member)

    user.verify_email!

    assert user.email_verified?
    assert user.active?
  end

  test "fresh_account? only applies to active users verified within the fresh-account window" do
    user = User.new(
      email: "fresh-check@example.com",
      pseudonym: "fresh_check",
      state: :active,
      email_verified_at: 2.hours.ago,
      reply_alerts_enabled: true
    )

    assert user.fresh_account?

    user.email_verified_at = 25.hours.ago
    assert_not user.fresh_account?

    user.email_verified_at = 2.hours.ago
    user.state = :pending_enrollment
    assert_not user.fresh_account?
  end

  test "verify_email does not reactivate suspended users" do
    user = users(:suspended_member)

    user.verify_email!

    assert user.suspended?
  end

  test "verify_totp accepts a valid current code" do
    user = users(:active_member)
    enroll_if_needed(user)

    assert user.verify_totp(valid_totp_code_for(user))
  end

  test "verify_totp rejects an invalid code" do
    user = users(:active_member)
    enroll_if_needed(user)

    refute user.verify_totp("000000")
  end

  test "verify_totp rejects a replayed code within the same window" do
    user = users(:active_member)
    enroll_if_needed(user)
    code = valid_totp_code_for(user)

    assert user.verify_totp(code)
    refute user.verify_totp(code), "same code must not be accepted twice"
  end

  test "verify_totp returns false when no secret is set" do
    user = users(:pending_member)

    refute user.verify_totp("123456")
  end

  test "begin_enrollment! generates a candidate secret and expiry" do
    user = users(:pending_member)
    assert_nil user.totp_candidate_secret

    user.begin_enrollment!

    assert user.reload.totp_candidate_secret.present?
    assert user.totp_candidate_secret_expires_at > 25.minutes.from_now
  end

  test "begin_enrollment! is idempotent while the candidate is unexpired" do
    user = users(:pending_member)
    user.begin_enrollment!
    first_secret = user.reload.totp_candidate_secret

    user.begin_enrollment!

    assert_equal first_secret, user.reload.totp_candidate_secret
  end

  test "begin_enrollment! regenerates the candidate after expiry" do
    user = users(:pending_member)
    user.begin_enrollment!
    first_secret = user.reload.totp_candidate_secret

    travel 31.minutes do
      user.begin_enrollment!
    end

    refute_equal first_secret, user.reload.totp_candidate_secret
  end

  test "begin_enrollment! does not modify totp_secret during recovery" do
    user = users(:active_member)
    enroll_if_needed(user)
    existing = user.totp_secret

    user.begin_enrollment!

    assert_equal existing, user.reload.totp_secret
    assert user.totp_candidate_secret.present?
    refute_equal existing, user.totp_candidate_secret
  end

  test "complete_enrollment! promotes candidate to in-use and clears candidate" do
    user = users(:pending_member)
    user.begin_enrollment!
    candidate = user.totp_candidate_secret

    user.complete_enrollment!

    user.reload
    assert_equal candidate, user.totp_secret
    assert_nil user.totp_candidate_secret
    assert_nil user.totp_candidate_secret_expires_at
  end

  test "complete_enrollment! transitions pending_enrollment to active and sets email_verified_at" do
    freeze_time do
      user = users(:pending_member)
      user.begin_enrollment!

      user.complete_enrollment!

      assert user.reload.active?
      assert_equal Time.current, user.email_verified_at
    end
  end

  test "complete_enrollment! bumps sessions_generation for active users (recovery)" do
    user = users(:active_member)
    enroll_if_needed(user)
    before = user.sessions_generation

    user.begin_enrollment!
    user.complete_enrollment!

    assert_equal before + 1, user.reload.sessions_generation
  end

  test "complete_enrollment! does NOT change email_verified_at on recovery" do
    user = users(:active_member)
    enroll_if_needed(user)
    original = user.email_verified_at

    user.begin_enrollment!
    user.complete_enrollment!

    assert_in_delta original, user.reload.email_verified_at, 1.second
  end

  test "generates_token_for :enrollment tokens are valid and round-trip" do
    user = users(:pending_member)

    token = user.generate_token_for(:enrollment)

    assert_equal user, User.find_by_token_for(:enrollment, token)
  end

  test "enrollment token is invalidated when enrollment_token_generation bumps" do
    user = users(:pending_member)
    token = user.generate_token_for(:enrollment)

    user.update!(enrollment_token_generation: user.enrollment_token_generation + 1)

    assert_nil User.find_by_token_for(:enrollment, token)
  end

  test "enrollment token is invalidated by first enrollment completion" do
    user = users(:pending_member)
    user.begin_enrollment!
    token = user.generate_token_for(:enrollment)

    user.complete_enrollment!

    assert_nil User.find_by_token_for(:enrollment, token)
  end
end
