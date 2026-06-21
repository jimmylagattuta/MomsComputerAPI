module V1
  module Auth
    class PhoneController < ApplicationController
      CODE_TTL = 10.minutes
      RESEND_WINDOW = 30.seconds
      MAX_ATTEMPTS = 6
      VERIFICATION_TOKEN_TTL = 15.minutes

      # POST /v1/auth/phone/request_code
      def request_code
        phone = normalize_phone(params[:phone])
        return render json: { error: "invalid_phone" }, status: :unprocessable_entity if phone.blank?

        if User.where(phone: phone).exists?
          return render json: {
            error: "validation_error",
            details: ["Phone has already been taken"]
          }, status: :unprocessable_entity
        end

        sent_at = Rails.cache.read(sent_at_key(phone))
        phone_debug("Existing sent_at", phone: phone, sent_at: sent_at)

        if sent_at.present? && Time.parse(sent_at.to_s) > RESEND_WINDOW.ago
          cooldown_remaining = [(Time.parse(sent_at.to_s) + RESEND_WINDOW - Time.current).ceil, 1].max
          return render json: {
            error: "too_many_requests",
            cooldown: cooldown_remaining
          }, status: :too_many_requests
        end

        now_iso = Time.current.iso8601

        Rails.cache.write(sent_at_key(phone), now_iso, expires_in: CODE_TTL)
        Rails.cache.write(attempts_key(phone), 0, expires_in: CODE_TTL)

        stored_sent_at_after_write = Rails.cache.read(sent_at_key(phone))
        stored_attempts_after_write = Rails.cache.read(attempts_key(phone))

        phone_debug("Requesting verification code", phone: phone)
        phone_debug("Cache store", class_name: Rails.cache.class.name)
        phone_debug("Stored sent_at after write", phone: phone, sent_at: stored_sent_at_after_write)
        phone_debug("Stored attempts after write", phone: phone, attempts: stored_attempts_after_write)

        verification = TwilioService.send_verification_code(to: phone)

        phone_debug("Verification code sent", phone: phone)
        phone_debug("Twilio Verify send result", sid: verification.sid, status: verification.status)

        render json: {
          ok: true,
          masked_phone: mask_phone(phone),
          cooldown: RESEND_WINDOW.to_i
        }
      rescue => e
        Rails.logger.error("SMS ERROR: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?
        render json: { error: "sms_send_failed" }, status: :unprocessable_entity
      end

      # POST /v1/auth/phone/verify_code
      def verify_code
        phone = normalize_phone(params[:phone])
        code = params[:code].to_s.strip.gsub(/\D/, "")[0, 6]

        return render json: { error: "invalid_phone" }, status: :unprocessable_entity if phone.blank?
        return render json: { error: "verification_code_invalid" }, status: :unprocessable_entity if code.length != 6

        stored_sent_at = Rails.cache.read(sent_at_key(phone))
        attempts = Rails.cache.read(attempts_key(phone)).to_i

        phone_debug("Verify cache store", class_name: Rails.cache.class.name)
        phone_debug("Verify stored sent_at", phone: phone, sent_at: stored_sent_at)
        phone_debug("Verify attempts", phone: phone, attempts: attempts)
        phone_debug("Submitted code", phone: phone, code: code) if Rails.env.development?

        return render json: { error: "verification_code_expired" }, status: :unprocessable_entity if stored_sent_at.blank?
        return render json: { error: "verification_code_expired" }, status: :unprocessable_entity if attempts >= MAX_ATTEMPTS

        verification_check = TwilioService.check_verification_code(to: phone, code: code)

        phone_debug(
          "Twilio Verify check result",
          sid: verification_check.sid,
          status: verification_check.status
        )

        unless verification_check.status == "approved"
          attempts += 1
          Rails.cache.write(attempts_key(phone), attempts, expires_in: CODE_TTL)

          phone_debug("Invalid code", phone: phone, attempts: attempts)

          return render json: { error: "verification_code_invalid" }, status: :unprocessable_entity
        end

        token = generate_token(phone)

        Rails.cache.delete(code_digest_key(phone))
        Rails.cache.delete(sent_at_key(phone))
        Rails.cache.delete(attempts_key(phone))

        phone_debug("Verification succeeded", phone: phone)

        render json: {
          ok: true,
          verification_token: token
        }
      rescue => e
        Rails.logger.error("VERIFY CODE ERROR: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace.present?
        render json: { error: "verification_code_invalid" }, status: :unprocessable_entity
      end

      private

      def phone_debug(message, data = {})
        return unless ENV["DEBUG_PHONE"] == "true"

        clean_data = data.compact.map { |key, value| "#{key}=#{value.inspect}" }.join(" ")
        Rails.logger.info("[PhoneController] #{message} #{clean_data}".strip)
      end

      def normalize_phone(value)
        digits = value.to_s.gsub(/\D/, "")
        digits = digits[1..] if digits.length == 11 && digits.start_with?("1")
        return nil unless digits.length == 10

        "+1#{digits}"
      end

      def digest(value)
        Digest::SHA256.hexdigest(value.to_s)
      end

      def secure_compare(a, b)
        return false if a.blank? || b.blank?
        return false unless a.bytesize == b.bytesize

        ActiveSupport::SecurityUtils.secure_compare(a, b)
      end

      def verifier
        Rails.application.message_verifier("phone_verification")
      end

      def generate_token(phone)
        verifier.generate(
          {
            phone: phone,
            purpose: "phone_verification",
            exp: VERIFICATION_TOKEN_TTL.from_now.to_i
          }
        )
      end

      def mask_phone(phone)
        "••••#{phone[-4..]}"
      end

      def code_digest_key(phone)
        "phone_verification:code_digest:#{phone}"
      end

      def sent_at_key(phone)
        "phone_verification:sent_at:#{phone}"
      end

      def attempts_key(phone)
        "phone_verification:attempts:#{phone}"
      end
    end
  end
end