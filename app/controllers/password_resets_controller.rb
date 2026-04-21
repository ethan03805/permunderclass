class PasswordResetsController < ApplicationController
  before_action :load_user_from_token, only: %i[edit update]

  def new; end

  def create
    if (user = User.find_by(email: password_reset_request_params[:email].to_s.strip.downcase))&.password_reset_permitted?
      UserMailer.password_reset(user).deliver_now
    end

    redirect_to sign_in_path, notice: t("auth.password_reset.create.success")
  end

  def edit
    @token = params[:token]
  end

  def update
    @token = params[:token]

    if password_reset_params[:password].blank?
      @user.assign_attributes(password_reset_params)
      @user.errors.add(:password, :blank)
      render :edit, status: :unprocessable_entity
      return
    end

    if @user.update(password_reset_params)
      start_session_for(@user)
      redirect_to root_path, notice: t("auth.password_reset.update.success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_user_from_token
    @user = User.find_by_token_for(:password_reset, params[:token])

    if @user.nil?
      redirect_to password_reset_path, alert: t("auth.password_reset.invalid")
      return
    end

    return if @user.password_reset_permitted?

    redirect_to sign_in_path, alert: blocked_user_message(@user)
  end

  def password_reset_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def password_reset_request_params
    params.require(:password_reset).permit(:email)
  end
end
