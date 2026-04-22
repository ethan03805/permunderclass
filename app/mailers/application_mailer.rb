class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "noreply@mail.permanentunderclass.me")
  layout "mailer"
end
