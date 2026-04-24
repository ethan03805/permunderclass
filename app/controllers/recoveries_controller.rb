class RecoveriesController < ApplicationController
  before_action :require_signed_out_user!

  def new; end

  def create
    unless turnstile_verified?
      redirect_to sign_in_path, notice: t("auth.recovery.submitted")
      return
    end

    email = recovery_params[:email].to_s.strip.downcase
    user = User.find_by(email: email) if email.present?

    if user && !user.suspended? && !user.banned?
      user.update!(enrollment_token_generation: user.enrollment_token_generation + 1)
      UserMailer.enrollment_link(user).deliver_later
    end

    redirect_to sign_in_path, notice: t("auth.recovery.submitted")
  end

  private

  def recovery_params
    params.require(:recovery).permit(:email)
  end
end
