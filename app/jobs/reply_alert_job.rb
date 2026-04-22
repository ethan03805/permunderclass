class ReplyAlertJob < ApplicationJob
  queue_as :mailers

  discard_on ActiveRecord::RecordNotFound

  def perform(comment_id)
    comment = Comment.includes(:user, post: :user, parent: :user).find(comment_id)
    return if comment.removed? || comment.post.removed?

    delivered_user_ids = []

    if eligible_recipient?(comment.parent&.user, actor: comment.user)
      ReplyAlertMailer.comment_reply(comment.parent.user, comment).deliver_now
      delivered_user_ids << comment.parent.user_id
    end

    post_author = comment.post.user
    if delivered_user_ids.exclude?(post_author.id) && eligible_recipient?(post_author, actor: comment.user)
      ReplyAlertMailer.post_comment(post_author, comment).deliver_now
    end
  end

  private

  def eligible_recipient?(recipient, actor:)
    recipient.present? && recipient != actor && recipient.active? && recipient.reply_alerts_enabled?
  end
end
