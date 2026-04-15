module V1
  module Admin
    class BaseController < ApplicationController
      include JwtAuth

      before_action :authenticate_user!
      before_action :require_admin!

      private

      def require_admin!
        return if current_user&.role == "admin"

        render json: { error: "forbidden" }, status: :forbidden
      end
    end
  end
end