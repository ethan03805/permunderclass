class ReportsController < ApplicationController
  before_action :require_verified_user!

  def create
    target = load_target
    report = current_user.reports_as_reporter.build(report_params.merge(target: target, status: :open))

    if report.save
      redirect_to_safe_return_path(report_fallback_path(target), anchor: params[:anchor], notice: t("reports.notices.created"))
    else
      redirect_to_safe_return_path(report_fallback_path(target), anchor: params[:anchor], alert: report.errors.full_messages.to_sentence)
    end
  end

  private

  def report_params
    params.require(:report).permit(:reason_code, :details)
  end

  def load_target
    target_class = {
      "Post" => Post,
      "Comment" => Comment,
      "User" => User
    }[params[:target_type].to_s]

    raise ActiveRecord::RecordNotFound if target_class.blank?

    target = target_class.find(params[:target_id])
    raise ActiveRecord::RecordNotFound unless report_target_visible?(target)

    target
  end

  def report_target_visible?(target)
    return false if target == current_user
    return false if target.respond_to?(:user) && target.user == current_user

    case target
    when Post
      target.visible_to?(current_user) && !target.removed?
    when Comment
      !target.removed? && target.post.visible_to?(current_user) && !target.post.removed?
    when User
      true
    else
      false
    end
  end

  def report_fallback_path(target)
    case target
    when Post
      post_path(target)
    when Comment
      post_path(target.post)
    when User
      profile_path(target.pseudonym)
    end
  end
end
