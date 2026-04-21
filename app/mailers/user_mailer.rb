class UserMailer < ApplicationMailer
  def email_verification(user)
    @user = user
    @verification_url = email_verification_url(token: user.generate_token_for(:email_verification))

    mail(
      subject: t("mailers.user_mailer.email_verification.subject"),
      to: user.email
    )
  end

  def password_reset(user)
    @user = user
    @password_reset_url = password_reset_token_url(token: user.generate_token_for(:password_reset))

    mail(
      subject: t("mailers.user_mailer.password_reset.subject"),
      to: user.email
    )
  end
end
