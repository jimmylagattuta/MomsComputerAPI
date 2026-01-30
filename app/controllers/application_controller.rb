# app/controllers/application_controller.rb
class ApplicationController < ActionController::API
  include ActionController::Cookies

  before_action :set_active_storage_url_options

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_bad_request

  private

  # ✅ Ensures ActiveStorage generates correct URLs in dev (LAN) + production (Heroku)
  def set_active_storage_url_options
    ActiveStorage::Current.url_options = {
      protocol: request.protocol.delete("://"),
      host: request.host,
      port: request.optional_port
    }
  end

  def render_not_found(e)
    render json: { error: "not_found", message: e.message }, status: :not_found
  end

  def render_bad_request(e)
    render json: { error: "bad_request", message: e.message }, status: :bad_request
  end
end