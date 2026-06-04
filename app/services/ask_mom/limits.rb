# app/services/ask_mom/limits.rb
# frozen_string_literal: true

module AskMom
  class Limits
    CONFIG = {
      guest: {
        messages_per_day: 15,
        images_per_day: 3,
        images_per_message: 1,
        conversations_per_day: 1,
        messages_per_conversation: 15,
        chars_per_message: 500,
        burst_messages: 2,
        burst_seconds: 10,
        support_unlocked: false
      },
      signed_in_free: {
        messages_per_day: 25,
        images_per_day: 5,
        images_per_message: 1,
        conversations_per_day: 3,
        messages_per_conversation: 25,
        chars_per_message: 800,
        burst_messages: 3,
        burst_seconds: 10,
        support_unlocked: false
      },
      subscriber: {
        messages_per_day: 150,
        images_per_day: 25,
        images_per_message: 3,
        conversations_per_day: 20,
        messages_per_conversation: 100,
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
      return :subscriber if subscribed?(user)

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
      return true if user.respond_to?(:support_subscription_active?) && user.support_subscription_active?
      return true if user.respond_to?(:subscription_active?) && user.subscription_active?
      return true if user.respond_to?(:subscribed?) && user.subscribed?

      if user.respond_to?(:subscription_status)
        return true if %w[active trialing].include?(user.subscription_status.to_s)
      end

      if user.respond_to?(:status)
        return true if %w[subscriber active_subscriber].include?(user.status.to_s)
      end

      false
    end
  end
end