# app/services/revenuecat/anonymous_subscription_active.rb
# frozen_string_literal: true

module Revenuecat
  class AnonymousSubscriptionActive
    ACTIVE_STATUSES = %w[
      anonymous_active
      anonymous_cancelled
    ].freeze

    def self.call(guest_id:)
      new(guest_id: guest_id).call
    end

    def initialize(guest_id:)
      @guest_id = guest_id.to_s.strip
    end

    def call
      return false if @guest_id.blank?

      link = RevenuecatCustomerLink
        .where(guest_id: @guest_id, user_id: nil)
        .order(updated_at: :desc)
        .first

      return false unless link
      return false unless ACTIVE_STATUSES.include?(link.status.to_s)

      active = link.expiration_at.blank? || link.expiration_at.future?

      Rails.logger.info(
        "[RC_ANON_SUB] guest_subscription_check " \
        "link_id=#{link.id} " \
        "status=#{link.status.inspect} " \
        "expiration_at=#{link.expiration_at.inspect} " \
        "active=#{active}"
      )

      active
    rescue => e
      Rails.logger.error(
        "[RC_ANON_SUB] guest_subscription_check_failed " \
        "error=#{e.class}: #{e.message}"
      )

      false
    end
  end
end