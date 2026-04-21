require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  include Rails.application.routes.url_helpers

  test "email verification email includes the verification link" do
    user = users(:pending_member)
    email = UserMailer.email_verification(user)

    assert_equal [ user.email ], email.to
    assert_equal I18n.t("mailers.user_mailer.email_verification.subject"), email.subject
    assert_match(%r{http://example\.com/email-verification/}, email.body.encoded)
  end

  test "password reset email includes the reset link" do
    user = users(:active_member)
    email = UserMailer.password_reset(user)

    assert_equal [ user.email ], email.to
    assert_equal I18n.t("mailers.user_mailer.password_reset.subject"), email.subject
    assert_match(%r{http://example\.com/password-reset/}, email.body.encoded)
  end
end
