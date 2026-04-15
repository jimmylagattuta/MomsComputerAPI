module V1
  module Auth
    class AuthController < ApplicationController
      include JwtAuth

      before_action :authenticate_user!, only: [:logout, :change_password]

      def signup
        user = User.new(signup_params)
        user.role ||= "senior"
        user.status ||= "active"

        if user.save
          begin
            UserMailer.welcome_email(user).deliver_later
          rescue => e
            Rails.logger.error("❌ [AUTH] welcome email failed for user_id=#{user.id}: #{e.class} - #{e.message}")
          end

          token = jwt_for(user)
          render json: { token: token, user: user_payload(user) }, status: :created
        else
          render json: {
            error: "validation_error",
            details: user.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      def login
        user = User.find_by(email: login_params[:email]&.downcase)

        if user&.authenticate(login_params[:password])
          user.update(last_login_at: Time.current, last_seen_at: Time.current)
          user.reload

          token = jwt_for(user)
          render json: { token: token, user: user_payload(user) }
        else
          render json: { error: "invalid_credentials" }, status: :unauthorized
        end
      end

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

      def change_password
        Rails.logger.info(
          "🔑 [AUTH] change_password user_id=#{current_user&.id} current_present=#{change_password_params[:current_password].present?} new_present=#{change_password_params[:password].present?} confirm_present=#{change_password_params[:password_confirmation].present?}"
        )

        unless current_user.authenticate(change_password_params[:current_password])
          Rails.logger.info("🔑 [AUTH] current password check failed for user_id=#{current_user&.id}")

          return render json: {
            error: "invalid_current_password",
            message: "Current password is incorrect"
          }, status: :unprocessable_entity
        end

        if change_password_params[:current_password] == change_password_params[:password]
          Rails.logger.info("🔑 [AUTH] new password matched current password for user_id=#{current_user&.id}")

          return render json: {
            error: "password_unchanged",
            message: "New password must be different from your current password"
          }, status: :unprocessable_entity
        end

        if current_user.update(
          password: change_password_params[:password],
          password_confirmation: change_password_params[:password_confirmation]
        )
          Rails.logger.info("🔑 [AUTH] password updated for user_id=#{current_user&.id}")

          render json: {
            ok: true,
            message: "Your password has been updated successfully"
          }
        else
          Rails.logger.info(
            "🔑 [AUTH] password update validation failed for user_id=#{current_user&.id}: #{current_user.errors.full_messages.join(', ')}"
          )

          render json: {
            error: "validation_error",
            details: current_user.errors.full_messages,
            message: current_user.errors.full_messages.to_sentence
          }, status: :unprocessable_entity
        end
      end

      private

      def signup_params
        params.require(:user).permit(
          :email,
          :password,
          :password_confirmation,
          :first_name,
          :last_name,
          :phone,
          :preferred_name,
          :preferred_language,
          :timezone
        ).tap { |p| p[:email] = p[:email].to_s.downcase }
      end

      def login_params
        params.require(:user).permit(:email, :password).tap do |p|
          p[:email] = p[:email].to_s.downcase
        end
      end

      def change_password_params
        if params[:auth].present?
          params.require(:auth).permit(:current_password, :password, :password_confirmation)
        else
          params.permit(:current_password, :password, :password_confirmation)
        end
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
          phone: user.phone,
          preferred_name: user.preferred_name,
          preferred_language: user.preferred_language,
          timezone: user.timezone,
          date_of_birth: user.date_of_birth,
          marketing_opt_in: user.marketing_opt_in,
          created_at: user.created_at,
          updated_at: user.updated_at,
          last_login_at: user.last_login_at,
          last_seen_at: user.last_seen_at,
          phone_verified_at: user.phone_verified_at
        }
      end
    end
  end
end