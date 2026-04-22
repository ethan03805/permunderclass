module Mod
  class UsersController < BaseController
    before_action :set_user

    def show
      @reports = Report.where(target: @user).includes(:reporter, :resolved_by).order(created_at: :desc)
      @recent_actions = @user.targeted_moderator_actions.includes(:moderator).order(created_at: :desc).limit(20)
      @posts = @user.posts.includes(:tags).order(published_at: :desc, id: :desc).limit(10)
      @comments = @user.comments.includes(:post).order(created_at: :desc, id: :desc).limit(10)
    end

    def moderate
      ActiveRecord::Base.transaction do
        @user.update!(state: moderation_params[:action_type].to_s.sub("user_", ""))
        ModeratorAction.create!(
          moderator: current_user,
          target: @user,
          action_type: moderation_params[:action_type],
          public_note: moderation_params[:public_note],
          internal_note: moderation_params[:internal_note],
          metadata: {}
        )
      end

      redirect_to mod_user_path(@user), notice: t("moderation.notices.#{user_notice_key}")
    rescue ActiveRecord::RecordInvalid => error
      redirect_to mod_user_path(@user), alert: error.record.errors.full_messages.to_sentence
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def moderation_params
      params.require(:moderation).permit(:action_type, :public_note, :internal_note)
    end

    def user_notice_key
      {
        "user_suspended" => "user_suspended",
        "user_banned" => "user_banned"
      }.fetch(moderation_params[:action_type].to_s)
    end
  end
end
