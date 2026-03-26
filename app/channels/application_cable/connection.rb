# app/channels/application_cable/connection.rb
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_jwt_payload

    JWT_ALG = "HS256".freeze

    def connect
      self.current_user, self.current_jwt_payload = find_verified_user
    end

    private

    def find_verified_user
      RevokedTokenCleanup.call

      token = request.params[:token].presence || bearer_token_from_headers
      raise "Unauthorized: Missing token" if token.blank?

      payload = decode_jwt(token)
      raise "Unauthorized: Invalid token" unless payload&.dig("user_id")

      jti = payload["jti"].to_s
      if jti.present? && RevokedToken.exists?(jti: jti)
        raise "Unauthorized: Token revoked"
      end

      user = User.find_by(id: payload["user_id"])
      raise "Unauthorized: Invalid user" unless user

      [user, payload]
    rescue StandardError => e
      Rails.logger.error("[ActionCable] Connection rejected: #{e.message}")
      reject_unauthorized_connection
    end

    def decode_jwt(token)
      secret = Rails.application.credentials.jwt_secret || ENV["JWT_SECRET"]
      raise "Missing JWT secret" if secret.blank?

      decoded, = JWT.decode(token, secret, true, { algorithm: JWT_ALG })
      decoded
    rescue JWT::DecodeError, JWT::ExpiredSignature
      nil
    end

    def bearer_token_from_headers
      auth_header = request.headers["Authorization"].to_s
      return nil unless auth_header.start_with?("Bearer ")

      auth_header.split(" ", 2).last
    end
  end
end