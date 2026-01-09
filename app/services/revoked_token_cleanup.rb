class RevokedTokenCleanup
  # Throttle cleanup to avoid deleting on every request
  CACHE_KEY = "revoked_tokens:last_cleanup_at".freeze
  EVERY_SECONDS = 60

  def self.call
    last = Rails.cache.read(CACHE_KEY).to_i
    now  = Time.now.to_i
    return if last > 0 && (now - last) < EVERY_SECONDS

    Rails.cache.write(CACHE_KEY, now)

    RevokedToken.where("expires_at < ?", Time.current).delete_all
  rescue => e
    Rails.logger.warn "⚠️ [AUTH] RevokedTokenCleanup failed: #{e.class}: #{e.message}"
  end
end