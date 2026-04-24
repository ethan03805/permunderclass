require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "enrollment_link delivers a signed link addressed to the user" do
    user = users(:pending_member)

    mail = UserMailer.enrollment_link(user)

    assert_equal [user.email], mail.to
    assert_equal I18n.t("mailers.user_mailer.enrollment_link.subject"), mail.subject
    assert_match %r{http://.+/enroll/[A-Za-z0-9_\-]+}, mail.body.encoded
  end

  test "enrollment_link body references the pseudonym" do
    user = users(:pending_member)

    mail = UserMailer.enrollment_link(user)

    assert_match user.pseudonym, mail.body.encoded
  end
end
