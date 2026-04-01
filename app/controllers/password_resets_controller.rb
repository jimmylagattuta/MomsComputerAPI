class PasswordResetsController < ActionController::Base
  layout false

  def edit
    @token = params[:token].to_s
    @email = params[:email].to_s.strip.downcase
    @error = nil
  end

  def update
    @token = params[:token].to_s
    @email = params[:email].to_s.strip.downcase
    @password = params[:password].to_s
    @password_confirmation = params[:password_confirmation].to_s

    user = User.find_by(email: @email)

    unless user&.valid_password_reset_token?(@token)
      @error = "That reset link is invalid or has expired."
      return render :edit, status: :unprocessable_entity
    end

    user.password = @password
    user.password_confirmation = @password_confirmation

    if user.save
      user.clear_password_reset_token!
      return render :success, status: :ok
    end

    @error = user.errors.full_messages.join(", ")
    render :edit, status: :unprocessable_entity
  end
end