class EmailVerificationsController < ApplicationController
  def show
    user = User.find_by_token_for(:email_verification, params[:token])

    if user.nil?
      redirect_to sign_in_path, alert: t("auth.email_verification.invalid")
      return
    end

    if user.suspended? || user.banned?
      redirect_to root_path, alert: blocked_user_message(user)
      return
    end

    if user.email_verified?
      redirect_to(email_verification_redirect_path, notice: t("auth.email_verification.already_verified"))
      return
    end

    user.verify_email!

    redirect_to(email_verification_redirect_path, notice: t("auth.email_verification.success"))
  end

  private

  def email_verification_redirect_path
    authenticated_user? ? root_path : sign_in_path
  end
end
