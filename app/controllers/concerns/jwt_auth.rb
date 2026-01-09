module JwtAuth
  extend ActiveSupport::Concern

  JWT_ALG = "HS256".freeze

  def current_jwt_payload
    @current_jwt_payload
  end

  def encode_jwt(payload, exp: 30.days.from_now)
    secret = Rails.application.credentials.jwt_secret || ENV["JWT_SECRET"]
    raise "Missing JWT secret" if secret.blank?

    # ensure jti exists for revocation
    payload = payload.merge(jti: payload[:jti] || payload["jti"] || SecureRandom.uuid)

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
    RevokedTokenCleanup.call

    token = bearer_token
    payload = token.present? ? decode_jwt(token) : nil

    unless payload&.dig("user_id")
      return render json: { error: "unauthorized" }, status: :unauthorized
    end

    jti = payload["jti"].to_s
    if jti.present? && RevokedToken.exists?(jti: jti)
      return render json: { error: "token_revoked" }, status: :unauthorized
    end

    @current_user = User.find_by(id: payload["user_id"])
    @current_jwt_payload = payload

    return if @current_user.present?

    render json: { error: "unauthorized" }, status: :unauthorized
  end

  def current_user
    @current_user
  end

  # NOW PUBLIC (used by AuthController#logout)
  def bearer_token
    header = request.headers["Authorization"]
    return nil if header.blank?

    scheme, token = header.split(" ", 2)
    scheme&.downcase == "bearer" ? token : nil
  end
end
