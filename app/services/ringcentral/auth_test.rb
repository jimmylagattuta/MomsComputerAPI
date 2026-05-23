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

      puts "[RingCentral AuthTest] Starting auth test..."
      puts "[RingCentral AuthTest] Server URL: #{server_url}"
      puts "[RingCentral AuthTest] Client ID present?: #{client_id.present?}"
      puts "[RingCentral AuthTest] Client Secret present?: #{client_secret.present?}"
      puts "[RingCentral AuthTest] JWT present?: #{jwt.present?}"

      rc = RingCentral.new(client_id, client_secret, server_url)

      puts "[RingCentral AuthTest] Authorizing with JWT..."
      rc.authorize(jwt: jwt)

      puts "[RingCentral AuthTest] Authorized. Fetching extension..."
      response = rc.get("/restapi/v1.0/account/~/extension/~")

      extension_data = response.body

      puts "[RingCentral AuthTest] Extension response class: #{extension_data.class}"
      puts "[RingCentral AuthTest] Extension response: #{extension_data.inspect}"

      {
        success: true,
        extension_id: extension_data["id"],
        extension_number: extension_data["extensionNumber"],
        name: extension_data["name"],
        status: extension_data["status"]
      }
    rescue StandardError => e
      puts "[RingCentral AuthTest] FAILED"
      puts "[RingCentral AuthTest] #{e.class.name}: #{e.message}"
      puts e.backtrace.first(10)

      {
        success: false,
        error_class: e.class.name,
        error_message: e.message
      }
    end
  end
end