module V1
  class MeController < ApplicationController
    include JwtAuth
    before_action :authenticate_user!

    def show
      u = current_user
      render json: {
        id: u.id,
        email: u.email,
        role: u.role,
        status: u.status,
        first_name: u.first_name,
        last_name: u.last_name,
        preferred_name: u.preferred_name,
        preferred_language: u.preferred_language,
        timezone: u.timezone
      }
    end
  end
end