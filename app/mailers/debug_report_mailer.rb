require "json"

class DebugReportMailer < ApplicationMailer
  default from: ENV.fetch("MAILER_FROM_EMAIL", "support@momscomputer.com")

  def debug_report
    @report = params.fetch(:report)
    @request_meta = params.fetch(:request_meta)

    @report_id = @request_meta[:report_id]

    @account =
      @report["account"].is_a?(Hash) ?
        @report["account"] :
        {}

    @user =
      @account["user"].is_a?(Hash) ?
        @account["user"] :
        {}

    @device =
      @report["device"].is_a?(Hash) ?
        @report["device"] :
        {}

    @app =
      @report["app"].is_a?(Hash) ?
        @report["app"] :
        {}

    @revenuecat =
      @report["revenueCat"].is_a?(Hash) ?
        @report["revenueCat"] :
        {}

    pretty_json =
      JSON.pretty_generate(
        {
          request: @request_meta,
          report: @report
        }
      )

    attachments["#{@report_id}.json"] = {
      mime_type: "application/json",
      content: pretty_json
    }

    recipient =
      ENV.fetch(
        "DEBUG_REPORT_TO_EMAIL",
        "jimmy.lagattuta@gmail.com"
      )

    email =
      @user["email"].to_s.strip.presence

    device_name =
      @device["deviceName"].to_s.strip.presence ||
      @device["modelName"].to_s.strip.presence ||
      @device["platform"].to_s.strip.presence ||
      "unknown-device"

    subject_bits = [
      "Mom's Computer debug report",
      email,
      device_name,
      @report_id
    ].compact

    mail(
      to: recipient,
      subject: subject_bits.join(" | ")
    )
  end
end