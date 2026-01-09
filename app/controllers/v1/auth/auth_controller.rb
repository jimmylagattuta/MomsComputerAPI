module V1
  module Auth
    class AuthController < ApplicationController
      include JwtAuth

      def signup
        user = User.new(signup_params)
        user.role ||= "senior"
        user.status ||= "active"

        if user.save
          token = jwt_for(user)
          render json: { token: token, user: user_payload(user) }, status: :created
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

      # REAL logout: revoke the current token
      def logout
        token = bearer_token
        payload = token.present? ? decode_jwt(token) : nil

        return render json: { error: "missing_token" }, status: :unauthorized unless token
        return render json: { error: "invalid_token" }, status: :unauthorized unless payload

        jti = payload["jti"].to_s
        exp = payload["exp"].to_i

        return render json: { error: "invalid_token" }, status: :unauthorized if jti.blank? || exp.zero?

        RevokedToken.create!(
          jti: jti,
          expires_at: Time.at(exp)
        )

        Rails.logger.info "🔒 [AUTH] logout revoked jti=#{jti} user_id=#{payload['user_id']}"

        render json: { ok: true }
      rescue ActiveRecord::RecordNotUnique
        render json: { ok: true }
      end

      private

      def signup_params
        params.require(:user).permit(
          :email, :password, :password_confirmation,
          :first_name, :last_name, :phone, :preferred_name,
          :preferred_language, :timezone
        ).tap { |p| p[:email] = p[:email].to_s.downcase }
      end

      def login_params
        params.require(:user).permit(:email, :password).tap { |p| p[:email] = p[:email].to_s.downcase }
      end

      def jwt_for(user)
        encode_jwt({ user_id: user.id, role: user.role }, exp: 30.days.from_now)
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
