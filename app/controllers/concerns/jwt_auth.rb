# app/controllers/concerns/jwt_auth.rb
module JwtAuth
  extend ActiveSupport::Concern

  JWT_ALG = "HS256".freeze

  def encode_jwt(payload, exp: 30.days.from_now)
    secret = Rails.application.credentials.jwt_secret || ENV["JWT_SECRET"]
    raise "Missing JWT secret" if secret.blank?

    JWT.encode(payload.merge(exp: exp.to_i), secret, JWT_ALG)
  end

  def decode_jwt(token)
    secret = Rails.application.credentials.jwt_secret || ENV["JWT_SECRET"]
    raise "Missing JWT secret" if secret.blank?

    decoded, = JWT.decode(token, secret, true, { algorithm: JWT_ALG })
    decoded
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end

  def authenticate_user!
    token = bearer_token
    payload = token.present? ? decode_jwt(token) : nil

    if payload&.dig("user_id")
      @current_user = User.find_by(id: payload["user_id"])
    end

    render json: { error: "unauthorized" }, status: :unauthorized if @current_user.nil?
  end

  def current_user
    @current_user
  end

  private

  def bearer_token
    header = request.headers["Authorization"]
    return nil if header.blank?
    scheme, token = header.split(" ", 2)
    scheme&.downcase == "bearer" ? token : nil
  end
end