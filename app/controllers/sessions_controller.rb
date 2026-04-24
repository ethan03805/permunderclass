class SessionsController < ApplicationController
  before_action :require_authenticated_user!, only: :destroy
  before_action :require_signed_out_user!, only: %i[create new]

  def new; end

  def create
    ip = request.remote_ip

    if LoginFailureTracker.blocked?(ip)
      redirect_to sign_in_path, alert: t("auth.sign_in.invalid_credentials")
      return
    end

    email = session_params[:email].to_s.strip.downcase
    code = session_params[:code].to_s
    user = User.find_by(email: email) if email.present?

    if user&.active? && !LoginFailureTracker.blocked_user?(user.id) && user.verify_totp(code)
      LoginFailureTracker.reset(ip)
      LoginFailureTracker.reset_user(user.id)
      start_session_for(user)
      redirect_to root_path, notice: t("auth.sign_in.success")
      return
    end

    LoginFailureTracker.track(ip)
    LoginFailureTracker.track_user(user.id) if user

    if user&.suspended? || user&.banned?
      redirect_to sign_in_path, alert: blocked_user_message(user)
    else
      redirect_to sign_in_path, alert: t("auth.sign_in.invalid_credentials")
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, notice: t("auth.sign_out.success")
  end

  private

  def session_params
    params.require(:session).permit(:email, :code)
  end
end
