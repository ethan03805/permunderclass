module Mod
  class PostsController < BaseController
    before_action :set_post

    def moderate
      ActiveRecord::Base.transaction do
        previous_status = @post.status

        case moderation_params[:action_type].to_s
        when "rewrite_requested"
          @post.update!(status: :rewrite_requested, rewrite_reason: moderation_params[:public_note])
        when "removed"
          @post.update!(status: :removed, rewrite_reason: nil)
        when "restored"
          @post.update!(status: :published, rewrite_reason: nil)
        else
          raise ActiveRecord::RecordInvalid, invalid_record(@post)
        end

        ModeratorAction.create!(
          moderator: current_user,
          target: @post,
          action_type: moderation_params[:action_type],
          public_note: moderation_params[:public_note],
          internal_note: moderation_params[:internal_note],
          metadata: { previous_status: previous_status }
        )
      end

      redirect_to post_path(@post), notice: t("moderation.notices.#{post_notice_key}")
    rescue ActiveRecord::RecordInvalid => error
      redirect_to post_path(@post), alert: error.record.errors.full_messages.to_sentence
    end

    private

    def set_post
      @post = Post.includes(:tags, :user, image_attachment: :blob, video_attachment: :blob).find_by_slugged_id!(params[:id])
    end

    def moderation_params
      params.require(:moderation).permit(:action_type, :public_note, :internal_note)
    end

    def post_notice_key
      {
        "rewrite_requested" => "rewrite_requested",
        "removed" => "post_removed",
        "restored" => "post_restored"
      }.fetch(moderation_params[:action_type].to_s)
    end

    def invalid_record(record)
      record.errors.add(:base, :invalid)
      record
    end
  end
end
