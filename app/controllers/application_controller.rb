class ApplicationController < ActionController::API
  include ActionController::Cookies

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_bad_request

  private

  def render_not_found(e)
    render json: { error: "not_found", message: e.message }, status: :not_found
  end

  def render_bad_request(e)
    render json: { error: "bad_request", message: e.message }, status: :bad_request
  end
end
