class SessionsController < ApplicationController
  before_action :require_authenticated_user!, only: :destroy
  before_action :require_signed_out_user!, only: %i[create new]

  def new; end

  def create
    user = User.authenticate_by(email: session_params[:email].to_s.strip.downcase, password: session_params[:password])

    if user.nil?
      redirect_to sign_in_path, alert: t("auth.sign_in.invalid_credentials")
      return
    end

    if user.suspended? || user.banned?
      redirect_to sign_in_path, alert: blocked_user_message(user)
      return
    end

    start_session_for(user)
    redirect_to root_path, notice: sign_in_notice_for(user)
  end

  def destroy
    terminate_session

    redirect_to root_path, notice: t("auth.sign_out.success")
  end

  private

  def session_params
    params.require(:session).permit(:email, :password)
  end

  def sign_in_notice_for(user)
    return t("auth.sign_in.pending_email_verification") unless user.email_verified?

    t("auth.sign_in.success")
  end
end
