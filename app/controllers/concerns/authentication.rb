module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :set_current_user

    helper_method :authenticated_user?, :current_user, :email_verified_user?, :moderation_user?
  end

  private

  def authenticated_user?
    current_user.present?
  end

  def current_user
    Current.user
  end

  def email_verified_user?
    current_user&.email_verified?
  end

  def moderation_user?
    current_user&.role.in?(%w[moderator admin])
  end

  def require_active_user!
    return if authenticated_user? && current_user.active?

    return redirect_to(sign_in_path, alert: t("auth.guards.authentication_required")) unless authenticated_user?
    return redirect_to(root_path, alert: t("auth.guards.email_verification_required")) if current_user.pending_email_verification?

    redirect_to root_path, alert: blocked_user_message(current_user)
  end

  def require_authenticated_user!
    return if authenticated_user?

    redirect_to sign_in_path, alert: t("auth.guards.authentication_required")
  end

  def require_signed_out_user!
    return unless authenticated_user?

    redirect_to root_path, alert: t("auth.guards.already_signed_in")
  end

  def require_verified_user!
    return if authenticated_user? && current_user.active? && current_user.email_verified?

    return redirect_to(sign_in_path, alert: t("auth.guards.authentication_required")) unless authenticated_user?
    return redirect_to(root_path, alert: blocked_user_message(current_user)) unless current_user.active? || current_user.pending_email_verification?

    redirect_to root_path, alert: t("auth.guards.email_verification_required")
  end

  def require_moderator!
    return if authenticated_user? && moderation_user?

    return redirect_to(sign_in_path, alert: t("auth.guards.authentication_required")) unless authenticated_user?

    redirect_to root_path, alert: t("auth.guards.moderation_required")
  end

  def set_current_user
    Current.user = User.find_by(id: session[:user_id]) if session[:user_id].present?
  end

  def start_session_for(user)
    reset_session
    session[:user_id] = user.id
    Current.user = user
  end

  def terminate_session
    reset_session
    Current.user = nil
  end

  def blocked_user_message(user)
    t("auth.guards.account_states.#{user.state}")
  end
end
