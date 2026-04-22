require "test_helper"

class ReplyAlertMailerTest < ActionMailer::TestCase
  include Rails.application.routes.url_helpers

  test "comment reply email includes the comment anchor" do
    email = ReplyAlertMailer.comment_reply(users(:moderator), comments(:reply_comment))

    assert_equal [ users(:moderator).email ], email.to
    assert_equal I18n.t("mailers.reply_alert_mailer.comment_reply.subject"), email.subject
    assert_match(%r{http://example\.com/posts/#{comments(:reply_comment).post.to_param}#comment-#{comments(:reply_comment).id}}, email.body.encoded)
  end

  test "post comment email includes the comment body" do
    email = ReplyAlertMailer.post_comment(users(:active_member), comments(:reply_comment))

    assert_equal [ users(:active_member).email ], email.to
    assert_equal I18n.t("mailers.reply_alert_mailer.post_comment.subject"), email.subject
    assert_includes email.body.encoded, comments(:reply_comment).body
  end
end
