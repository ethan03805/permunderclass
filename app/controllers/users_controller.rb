class UsersController < ApplicationController
  before_action :require_signed_out_user!, only: %i[create new]

  def new
    @user = User.new(reply_alerts_enabled: true)
  end

  def create
    @user = User.new(user_params)

    unless turnstile_verified?
      @user.errors.add(:base, :turnstile_failed)
      render :new, status: :unprocessable_entity
      return
    end

    if @user.save
      start_session_for(@user)
      UserMailer.email_verification(@user).deliver_now

      redirect_to root_path, notice: t("auth.sign_up.success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def turnstile_verified?
    TurnstileVerification.new(
      token: params["cf-turnstile-response"],
      remote_ip: request.remote_ip
    ).verified?
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :pseudonym)
  end
end
