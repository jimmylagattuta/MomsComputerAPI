class UserMailer < ApplicationMailer
  def welcome_email(user)
    @user = user

    mail(
      to: @user.email,
      subject: "Welcome to Mom's Computer"
    )
  end

  def password_reset_email(user, raw_token)
    @user = user
    @raw_token = raw_token
    @reset_url = "#{ENV.fetch('APP_BASE_URL')}/password_resets/edit?token=#{CGI.escape(raw_token)}&email=#{CGI.escape(user.email)}"

    mail(
      to: @user.email,
      subject: "Reset your Mom's Computer password"
    )
  end
end