# app/controllers/v1/auth/auth_controller.rb
module V1
  module Auth
    class AuthController < ApplicationController
      # No JWT auth for these endpoints
      def signup
        user = User.new(signup_params)
        user.role ||= "senior"
        user.status ||= "active"

        if user.save
          token = jwt_for(user)
          render json: {
            token: token,
            user: user_payload(user)
          }, status: :created
        else
          render json: { error: "validation_error", details: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def login
        user = User.find_by(email: login_params[:email]&.downcase)
        if user&.authenticate(login_params[:password])
          user.update(last_login_at: Time.current, last_seen_at: Time.current)
          token = jwt_for(user)
          render json: { token: token, user: user_payload(user) }
        else
          render json: { error: "invalid_credentials" }, status: :unauthorized
        end
      end

      private

      def signup_params
        params.require(:user).permit(
          :email, :password, :password_confirmation,
          :first_name, :last_name, :phone, :preferred_name,
          :preferred_language, :timezone
        ).tap do |p|
          p[:email] = p[:email].to_s.downcase
        end
      end

      def login_params
        params.require(:user).permit(:email, :password).tap do |p|
          p[:email] = p[:email].to_s.downcase
        end
      end

      def jwt_for(user)
        secret = Rails.application.credentials.jwt_secret || ENV["JWT_SECRET"]
        raise "Missing JWT secret" if secret.blank?

        JWT.encode({ user_id: user.id, role: user.role, exp: 30.days.from_now.to_i }, secret, "HS256")
      end

      def user_payload(user)
        {
          id: user.id,
          email: user.email,
          role: user.role,
          status: user.status,
          first_name: user.first_name,
          last_name: user.last_name,
          preferred_name: user.preferred_name,
          preferred_language: user.preferred_language,
          timezone: user.timezone
        }
      end
    end
  end
end