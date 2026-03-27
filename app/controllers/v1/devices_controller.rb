module V1
  class DevicesController < ApplicationController
    include JwtAuth

    before_action :debug_auth_header
    before_action :authenticate_user!

    def register
      attrs = device_params

      device = current_user.devices.find_or_initialize_by(
        platform: attrs[:platform].to_s,
        device_name: attrs[:device_name].to_s
      )

      device.os_version   = attrs[:os_version]
      device.app_version  = attrs[:app_version]
      device.push_token   = attrs[:push_token]
      device.last_seen_at = Time.current
      device.last_ip      = request.remote_ip

      if device.save
        render json: {
          ok: true,
          device: {
            id: device.id,
            platform: device.platform,
            device_name: device.device_name,
            push_token: device.push_token,
            last_seen_at: device.last_seen_at
          }
        }, status: :ok
      else
        render json: {
          ok: false,
          errors: device.errors.full_messages
        }, status: :unprocessable_entity
      end
    end

    private

    def debug_auth_header
    #   Rails.logger.info("===== DEVICES REGISTER AUTH DEBUG =====")
    #   Rails.logger.info("Authorization header: #{request.headers['Authorization'].inspect}")
    #   Rails.logger.info("Remote IP: #{request.remote_ip}")
    #   Rails.logger.info("=======================================")
    end

    def device_params
      params.require(:device).permit(
        :platform,
        :device_name,
        :os_version,
        :app_version,
        :push_token,
        :notifications_enabled
      )
    end
  end
end