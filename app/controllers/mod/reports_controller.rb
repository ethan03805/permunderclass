module Mod
  class ReportsController < BaseController
    before_action :set_report, only: [ :show, :update ]

    def index
      @open_reports = Report.open.includes(:reporter, :target).order(created_at: :asc)
      @recent_actions = ModeratorAction.includes(:moderator, :target).order(created_at: :desc).limit(25)
    end

    def show
      @related_reports = Report.where(target: @report.target).includes(:reporter, :resolved_by).order(created_at: :desc)
      @recent_target_actions = @report.target.moderator_actions.includes(:moderator).order(created_at: :desc).limit(20)
    end

    def update
      decision = moderation_params[:decision].to_s

      ActiveRecord::Base.transaction do
        case decision
        when "dismiss_report"
          dismiss_report!
        when "rewrite_requested"
          moderate_post_from_report!(:rewrite_requested)
        when "removed"
          moderate_post_from_report!(:removed)
        when "comment_removed"
          moderate_comment_from_report!
        when "user_suspended"
          moderate_user_from_report!(:user_suspended)
        when "user_banned"
          moderate_user_from_report!(:user_banned)
        else
          raise ActiveRecord::RecordInvalid, @report
        end
      end

      redirect_to mod_report_path(@report), notice: t("moderation.notices.#{notice_key_for(decision)}")
    rescue ActiveRecord::RecordInvalid => error
      redirect_to mod_report_path(@report), alert: error.record.errors.full_messages.to_sentence
    end

    private

    def set_report
      @report = Report.includes(:reporter, :resolved_by, :moderator_actions).find(params[:id])
    end

    def moderation_params
      params.require(:moderation).permit(:decision, :public_note, :internal_note)
    end

    def dismiss_report!
      log_action!(
        target: @report,
        action_type: :report_dismissed,
        metadata: {
          target_type: @report.target_type,
          target_id: @report.target_id
        }
      )
      resolve_report!(:dismissed)
    end

    def moderate_post_from_report!(action_type)
      post = @report.target
      raise ActiveRecord::RecordInvalid, invalid_record(post) unless post.is_a?(Post)

      previous_status = post.status
      attributes =
        if action_type.to_sym == :rewrite_requested
          { status: :rewrite_requested, rewrite_reason: moderation_params[:public_note] }
        else
          { status: :removed, rewrite_reason: nil }
        end

      post.update!(attributes)
      log_action!(
        target: post,
        action_type: action_type,
        metadata: { report_id: @report.id, previous_status: previous_status }
      )
      resolve_report!(:resolved)
    end

    def moderate_comment_from_report!
      comment = @report.target
      raise ActiveRecord::RecordInvalid, invalid_record(comment) unless comment.is_a?(Comment)

      comment.update!(status: :removed)
      log_action!(
        target: comment,
        action_type: :comment_removed,
        metadata: { report_id: @report.id }
      )
      resolve_report!(:resolved)
    end

    def moderate_user_from_report!(action_type)
      user = @report.target
      raise ActiveRecord::RecordInvalid, invalid_record(user) unless user.is_a?(User)

      user.update!(state: action_type.to_s.sub("user_", ""))
      log_action!(
        target: user,
        action_type: action_type,
        metadata: { report_id: @report.id }
      )
      resolve_report!(:resolved)
    end

    def resolve_report!(status)
      @report.update!(status: status, resolved_by: current_user, resolved_at: Time.current)
    end

    def log_action!(target:, action_type:, metadata: {})
      ModeratorAction.create!(
        moderator: current_user,
        target: target,
        action_type: action_type,
        public_note: moderation_params[:public_note],
        internal_note: moderation_params[:internal_note],
        metadata: metadata
      )
    end

    def invalid_record(record)
      record.errors.add(:base, :invalid)
      record
    end

    def notice_key_for(decision)
      {
        "dismiss_report" => "report_dismissed",
        "rewrite_requested" => "rewrite_requested",
        "removed" => "post_removed",
        "comment_removed" => "comment_removed",
        "user_suspended" => "user_suspended",
        "user_banned" => "user_banned"
      }.fetch(decision)
    end
  end
end
