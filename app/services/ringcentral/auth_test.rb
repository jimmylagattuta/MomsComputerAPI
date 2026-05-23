# app/services/ringcentral/auth_test.rb

require "ringcentral"

module Ringcentral
  class AuthTest
    def self.call
      new.call
    end

    def call
      client_id = ENV.fetch("RINGCENTRAL_CLIENT_ID")
      client_secret = ENV.fetch("RINGCENTRAL_CLIENT_SECRET")
      server_url = ENV.fetch("RINGCENTRAL_SERVER_URL")
      jwt = ENV.fetch("RINGCENTRAL_JWT")

      platform = RingCentral.new(client_id, client_secret, server_url)

      platform.authorize(jwt: jwt)

      extension_response = platform.get("/restapi/v1.0/account/~/extension/~")
      extension_data = JSON.parse(extension_response.body)

      {
        success: true,
        extension_id: extension_data["id"],
        extension_number: extension_data["extensionNumber"],
        name: extension_data["name"],
        status: extension_data["status"]
      }
    rescue StandardError => e
      {
        success: false,
        error_class: e.class.name,
        error_message: e.message
      }
    end
  end
end