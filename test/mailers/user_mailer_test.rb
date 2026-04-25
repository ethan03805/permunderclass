require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "enrollment_link delivers a signed link addressed to the user" do
    user = users(:pending_member)

    mail = UserMailer.enrollment_link(user)

    assert_equal [ user.email ], mail.to
    assert_equal I18n.t("mailers.user_mailer.enrollment_link.subject"), mail.subject
    assert_not_nil mail.html_part, "HTML part missing"
    assert_not_nil mail.text_part, "text part missing"
    assert_match %r{/enroll/[A-Za-z0-9_\-]+}, mail.html_part.body.encoded
    assert_match %r{/enroll/[A-Za-z0-9_\-]+}, mail.text_part.body.encoded
  end

  test "enrollment_link body references the pseudonym in both parts" do
    user = users(:pending_member)

    mail = UserMailer.enrollment_link(user)

    assert_match user.pseudonym, mail.html_part.body.encoded
    assert_match user.pseudonym, mail.text_part.body.encoded
  end
end
