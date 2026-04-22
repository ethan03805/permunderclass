module Mod
  class CommentsController < BaseController
    before_action :set_comment

    def moderate
      ActiveRecord::Base.transaction do
        @comment.update!(status: :removed)
        ModeratorAction.create!(
          moderator: current_user,
          target: @comment,
          action_type: :comment_removed,
          public_note: moderation_params[:public_note],
          internal_note: moderation_params[:internal_note],
          metadata: { post_id: @comment.post_id }
        )
      end

      redirect_to post_path(@comment.post, anchor: "comment-#{@comment.id}"), notice: t("moderation.notices.comment_removed")
    rescue ActiveRecord::RecordInvalid => error
      redirect_to post_path(@comment.post, anchor: "comment-#{@comment.id}"), alert: error.record.errors.full_messages.to_sentence
    end

    private

    def set_comment
      @comment = Comment.includes(:post).find(params[:id])
    end

    def moderation_params
      params.require(:moderation).permit(:public_note, :internal_note)
    end
  end
end
