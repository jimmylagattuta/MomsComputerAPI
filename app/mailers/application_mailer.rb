class ApplicationMailer < ActionMailer::Base
  default from: "Mom's Computer <#{ENV.fetch("GMAIL_SMTP_USERNAME")}>"
  layout "mailer"
end