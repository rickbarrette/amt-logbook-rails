class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "AMT Logbook <no-reply@example.com>")
  layout "mailer"
end
