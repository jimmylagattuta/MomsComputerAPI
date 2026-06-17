module V1
  module Auth
    class AuthController < ApplicationController
      include JwtAuth

      before_action :authenticate_user!, only: [:logout, :change_password]

      DEFAULT_MONTHLY_CALL_LIMIT = 3

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
        call_usage = call_usage_payload_for(user)

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
          phone_verified_at: user.phone_verified_at,

          # ✅ Backend/Rails premium access for the mobile app gate
          support_subscription_active: support_subscription_active_for(user),

          # ✅ Call usage fields for the mobile app settings menu
          current_calls_this_month: call_usage[:current_calls_this_month],
          monthly_call_limit: call_usage[:monthly_call_limit],
          calls_left_this_month: call_usage[:calls_left_this_month],

          # ✅ Extra debug-friendly fields
          active_call_cycle_id: call_usage[:active_call_cycle_id],
          call_cycle_start_at: call_usage[:call_cycle_start_at],
          call_cycle_end_at: call_usage[:call_cycle_end_at]
        }
      end

      def support_subscription_active_for(user)
        return false unless user
        return true if admin_user?(user)

        if user.respond_to?(:support_subscription_active?)
          user.support_subscription_active?
        else
          false
        end
      rescue => e
        Rails.logger.error("❌ [AUTH] support_subscription_active_for failed user_id=#{user&.id}: #{e.class} - #{e.message}")
        false
      end

      def call_usage_payload_for(user)
        return default_call_usage_payload unless user

        active_cycle = active_support_call_cycle_for(user)

        calls_allowed =
          if active_cycle
            active_cycle.calls_allowed.to_i
          elsif admin_user?(user)
            999
          else
            DEFAULT_MONTHLY_CALL_LIMIT
          end

        calls_used =
          if active_cycle
            active_cycle.calls_used.to_i
          else
            0
          end

        calls_left = [calls_allowed - calls_used, 0].max

        Rails.logger.info(
          "📞 [AUTH] call usage payload user_id=#{user.id} cycle_id=#{active_cycle&.id} calls_used=#{calls_used} calls_allowed=#{calls_allowed} calls_left=#{calls_left}"
        )

        {
          current_calls_this_month: calls_used,
          monthly_call_limit: calls_allowed,
          calls_left_this_month: calls_left,
          active_call_cycle_id: active_cycle&.id,
          call_cycle_start_at: active_cycle&.cycle_start_at,
          call_cycle_end_at: active_cycle&.cycle_end_at
        }
      rescue => e
        Rails.logger.error("❌ [AUTH] call_usage_payload_for failed user_id=#{user&.id}: #{e.class} - #{e.message}")
        default_call_usage_payload
      end

      def active_support_call_cycle_for(user)
        return nil unless defined?(SupportCallCycle)

        SupportCallCycle
          .where(user_id: user.id)
          .where("cycle_start_at <= ? AND cycle_end_at >= ?", Time.current, Time.current)
          .order(cycle_start_at: :desc)
          .first
      rescue => e
        Rails.logger.error("❌ [AUTH] active_support_call_cycle_for failed user_id=#{user&.id}: #{e.class} - #{e.message}")
        nil
      end

      def default_call_usage_payload
        {
          current_calls_this_month: 0,
          monthly_call_limit: DEFAULT_MONTHLY_CALL_LIMIT,
          calls_left_this_month: DEFAULT_MONTHLY_CALL_LIMIT,
          active_call_cycle_id: nil,
          call_cycle_start_at: nil,
          call_cycle_end_at: nil
        }
      end

      def admin_user?(user)
        user.role.to_s == "admin" ||
          user.role.to_s == "super_admin" ||
          (user.respond_to?(:admin?) && user.admin?)
      end
    end
  end
end