module V1
  module Auth
    class PasswordResetsController < ApplicationController
      rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

      def create
        Rails.logger.info "🔑 [PASSWORD_RESET] raw params: #{params.to_unsafe_h.inspect}"

        email = create_params[:email]
        user = User.find_by(email: email)

        if user.present?
          raw_token = user.generate_password_reset_token!
          UserMailer.password_reset_email(user, raw_token).deliver_now
        end

        render json: {
          ok: true,
          message: "If that email is in our system, a reset link has been sent."
        }, status: :ok
      end

      def update
        Rails.logger.info "🔑 [PASSWORD_RESET] raw params: #{params.to_unsafe_h.inspect}"

        user = User.find_by(email: update_params[:email])

        unless user&.valid_password_reset_token?(update_params[:token])
          return render json: {
            error: "invalid_or_expired_reset_token"
          }, status: :unprocessable_entity
        end

        user.password = update_params[:password]
        user.password_confirmation = update_params[:password_confirmation]

        if user.save
          user.clear_password_reset_token!

          render json: {
            ok: true,
            message: "Your password has been reset."
          }, status: :ok
        else
          render json: {
            error: "validation_error",
            details: user.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def create_params
        permitted = params.require(:password_reset).permit(:email)
        permitted[:email] = permitted[:email].to_s.strip.downcase
        permitted
      end

      def update_params
        permitted = params.require(:password_reset).permit(
          :email,
          :token,
          :password,
          :password_confirmation
        )
        permitted[:email] = permitted[:email].to_s.strip.downcase
        permitted
      end

      def handle_parameter_missing(error)
        Rails.logger.error "❌ [PASSWORD_RESET] Parameter missing: #{error.message}"
        render json: {
          error: "missing_parameters",
          details: [error.message]
        }, status: :bad_request
      end
    end
  end
end