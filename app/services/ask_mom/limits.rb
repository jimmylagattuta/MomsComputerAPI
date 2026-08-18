# app/services/ask_mom/limits.rb
# frozen_string_literal: true

module AskMom
  class Limits
    ACTIVE_SUBSCRIPTION_STATUSES = %w[
      active
      trialing
      paid
      subscribed
      cancelled
    ].freeze

    CONFIG = {
      guest: {
        messages_per_day: 3,
        images_per_day: 3,
        images_per_message: 1,
        conversations_per_day: 1,
        messages_per_conversation: 3,
        chars_per_message: 500,
        burst_messages: 2,
        burst_seconds: 10,
        support_unlocked: false
      },

      signed_in_free: {
        messages_per_day: 3,
        images_per_day: 5,
        images_per_message: 1,
        conversations_per_day: 3,
        messages_per_conversation: 3,
        chars_per_message: 800,
        burst_messages: 3,
        burst_seconds: 10,
        support_unlocked: false
      },

      subscriber: {
        messages_per_day: 1_000_000,
        images_per_day: 25,
        images_per_message: 3,
        conversations_per_day: 1_000_000,
        messages_per_conversation: 1_000_000,
        chars_per_message: 2500,
        burst_messages: 5,
        burst_seconds: 10,
        support_unlocked: true
      },

      admin: {
        messages_per_day: 1000,
        images_per_day: 100,
        images_per_message: 5,
        conversations_per_day: 100,
        messages_per_conversation: 300,
        chars_per_message: 5000,
        burst_messages: 10,
        burst_seconds: 10,
        support_unlocked: true
      }
    }.freeze

    def self.for_guest
      CONFIG.fetch(:guest)
    end

    def self.for_user(user)
      CONFIG.fetch(tier_for_user(user))
    end

    def self.tier_for_user(user)
      return :guest unless user
      return :admin if admin?(user)

      if subscribed?(user)
        Rails.logger.info(
          "[AskMom::Limits] tier_decision user_id=#{user.id} tier=subscriber"
        )

        return :subscriber
      end

      Rails.logger.info(
        "[AskMom::Limits] tier_decision user_id=#{user.id} tier=signed_in_free"
      )

      :signed_in_free
    end

    def self.admin?(user)
      return true if user.respond_to?(:admin?) && user.admin?
      return true if user.respond_to?(:admin) && user.admin == true
      return true if user.respond_to?(:is_admin) && user.is_admin == true

      role = user.respond_to?(:role) ? user.role.to_s : ""

      %w[admin super_admin].include?(role)
    end

    def self.subscribed?(user)
      subscription = active_revenuecat_subscription(user)
      entitlement = active_revenuecat_entitlement(user)

      result = subscription.present? || entitlement.present?

      Rails.logger.info(
        "[AskMom::Limits] subscription_check " \
        "user_id=#{user.id} " \
        "subscription_active=#{subscription.present?} " \
        "subscription_id=#{subscription&.id.inspect} " \
        "subscription_status=#{subscription&.status.inspect} " \
        "subscription_period_end=#{subscription&.current_period_end.inspect} " \
        "entitlement_active=#{entitlement.present?} " \
        "entitlement_id=#{entitlement&.id.inspect} " \
        "entitlement_key=#{entitlement&.key.inspect} " \
        "entitlement_expires_at=#{entitlement&.expires_at.inspect} " \
        "result=#{result}"
      )

      result
    rescue => e
      Rails.logger.error(
        "[AskMom::Limits] subscription_check_failed " \
        "user_id=#{user&.id.inspect} " \
        "error=#{e.class}: #{e.message}"
      )

      false
    end

    def self.active_revenuecat_subscription(user)
      return nil unless user.respond_to?(:subscriptions)

      user.subscriptions
          .where(provider: "revenuecat")
          .where(status: ACTIVE_SUBSCRIPTION_STATUSES)
          .where(
            "current_period_end IS NULL OR current_period_end > ?",
            Time.current
          )
          .order(current_period_end: :desc)
          .first
    end

    def self.active_revenuecat_entitlement(user)
      return nil unless user.respond_to?(:entitlements)

      user.entitlements
          .where(source: "revenuecat", enabled: true)
          .where(
            "expires_at IS NULL OR expires_at > ?",
            Time.current
          )
          .order(expires_at: :desc)
          .first
    end

    private_class_method :active_revenuecat_subscription
    private_class_method :active_revenuecat_entitlement
  end
end