class UserMailer < ApplicationMailer
  def enrollment_link(user)
    @user = user
    @enrollment_url = enroll_url(token: user.generate_token_for(:enrollment))

    mail(
      subject: t("mailers.user_mailer.enrollment_link.subject"),
      to: user.email
    )
  end
end
