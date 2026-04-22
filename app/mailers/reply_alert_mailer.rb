class ReplyAlertMailer < ApplicationMailer
  def comment_reply(recipient, comment)
    assign_comment_context(recipient, comment)

    mail(
      subject: t("mailers.reply_alert_mailer.comment_reply.subject"),
      to: recipient.email
    )
  end

  def post_comment(recipient, comment)
    assign_comment_context(recipient, comment)

    mail(
      subject: t("mailers.reply_alert_mailer.post_comment.subject"),
      to: recipient.email
    )
  end

  private

  def assign_comment_context(recipient, comment)
    @recipient = recipient
    @comment = comment
    @comment_author = comment.user
    @post = comment.post
    @comment_url = post_url(@post, anchor: "comment-#{comment.id}")
  end
end
