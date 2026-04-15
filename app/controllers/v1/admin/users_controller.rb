module V1
  module Admin
    class UsersController < BaseController
      def index
        users = User.order(created_at: :desc)
        render json: { users: users.map { |user| user_payload(user) } }
      end

      def show
        user = User.find(params[:id])
        render json: { user: user_payload(user) }
      end

      def update
        user = User.find(params[:id])

        if user.update(user_params)
          render json: { user: user_payload(user) }
        else
          render json: {
            error: "validation_error",
            details: user.errors.full_messages,
            message: user.errors.full_messages.to_sentence
          }, status: :unprocessable_entity
        end
      end

      private

      def user_params
        params.require(:user).permit(
          :email,
          :first_name,
          :last_name,
          :phone,
          :preferred_name,
          :preferred_language,
          :timezone,
          :role,
          :status,
          :marketing_opt_in,
          :date_of_birth
        ).tap do |p|
          p[:email] = p[:email].to_s.downcase if p[:email].present?
        end
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