module V1
  class MeController < ApplicationController
    include JwtAuth

    before_action :authenticate_user!

    DEFAULT_MONTHLY_CALL_LIMIT = 1

    def show
      u = current_user
      call_usage = call_usage_payload_for(u)

      render json: {
        id: u.id,
        email: u.email,
        role: u.role,
        status: u.status,
        first_name: u.first_name,
        last_name: u.last_name,
        phone: u.phone,
        preferred_name: u.preferred_name,
        preferred_language: u.preferred_language,
        timezone: u.timezone,
        date_of_birth: u.date_of_birth,
        marketing_opt_in: u.marketing_opt_in,
        created_at: u.created_at,
        updated_at: u.updated_at,
        last_login_at: u.last_login_at,
        last_seen_at: u.last_seen_at,
        phone_verified_at: u.phone_verified_at,

        # âœ… Backend/Rails premium access for the mobile app gate
        support_subscription_active: support_subscription_active_for(u),
        support_calls_unlimited: call_usage[:support_calls_unlimited],

        # âœ… Call usage fields for the mobile app settings menu
        current_calls_this_month: call_usage[:current_calls_this_month],
        monthly_call_limit: call_usage[:monthly_call_limit],
        calls_left_this_month: call_usage[:calls_left_this_month],

        # âœ… Extra debug-friendly fields
        active_call_cycle_id: call_usage[:active_call_cycle_id],
        call_cycle_start_at: call_usage[:call_cycle_start_at],
        call_cycle_end_at: call_usage[:call_cycle_end_at]
      }
    end

    def destroy
      user = current_user

      Rails.logger.info("ðŸ§¹ [ME] account deletion requested user_id=#{user.id}")

      user.delete_account!

      Rails.logger.info("ðŸ§¹ [ME] account deleted/anonymized user_id=#{user.id}")

      render json: {
        ok: true,
        message: "Your account has been deleted."
      }
    rescue => e
      Rails.logger.error(
        "âŒ [ME] account deletion failed user_id=#{current_user&.id}: #{e.class} - #{e.message}"
      )

      render json: {
        error: "account_deletion_failed",
        message: "We could not delete your account right now. Please try again."
      }, status: :unprocessable_entity
    end

    private

    def support_subscription_active_for(user)
      return false unless user
      return true if admin_user?(user)

      if user.respond_to?(:support_subscription_active?)
        user.support_subscription_active?
      else
        false
      end
    rescue => e
      Rails.logger.error("âŒ [ME] support_subscription_active_for failed user_id=#{user&.id}: #{e.class} - #{e.message}")
      false
    end

    def call_usage_payload_for(user)
      return default_call_usage_payload unless user

      active_cycle = active_support_call_cycle_for(user)

      unlimited = support_calls_unlimited_for(user)

      calls_allowed =
        if unlimited
          999
        elsif active_cycle
          active_cycle.calls_allowed.to_i
        else
          DEFAULT_MONTHLY_CALL_LIMIT
        end

      calls_used =
        if active_cycle
          active_cycle.calls_used.to_i
        else
          0
        end

      calls_left = [calls_allowed - calls_used, 0].max

      Rails.logger.info(
        "ðŸ“ž [ME] call usage payload user_id=#{user.id} cycle_id=#{active_cycle&.id} calls_used=#{calls_used} calls_allowed=#{calls_allowed} calls_left=#{calls_left}"
      )

      {
        current_calls_this_month: calls_used,
        monthly_call_limit: calls_allowed,
        support_calls_unlimited: unlimited,
        calls_left_this_month: calls_left,
        active_call_cycle_id: active_cycle&.id,
        call_cycle_start_at: active_cycle&.cycle_start_at,
        call_cycle_end_at: active_cycle&.cycle_end_at
      }
    rescue => e
      Rails.logger.error("âŒ [ME] call_usage_payload_for failed user_id=#{user&.id}: #{e.class} - #{e.message}")
      default_call_usage_payload
    end

    def active_support_call_cycle_for(user)
      return nil unless defined?(SupportCallCycle)

      SupportCallCycle
        .where(user_id: user.id)
        .where("cycle_start_at <= ? AND cycle_end_at >= ?", Time.current, Time.current)
        .order(cycle_start_at: :desc)
        .first
    rescue => e
      Rails.logger.error("âŒ [ME] active_support_call_cycle_for failed user_id=#{user&.id}: #{e.class} - #{e.message}")
      nil
    end

    def default_call_usage_payload
      {
        current_calls_this_month: 0,
        monthly_call_limit: DEFAULT_MONTHLY_CALL_LIMIT,
        calls_left_this_month: DEFAULT_MONTHLY_CALL_LIMIT,
        support_calls_unlimited: false,
        active_call_cycle_id: nil,
        call_cycle_start_at: nil,
        call_cycle_end_at: nil
      }
    end

    def support_calls_unlimited_for(user)
      return false unless user
      return user.support_calls_unlimited? if user.respond_to?(:support_calls_unlimited?)

      admin_user?(user) || support_subscription_active_for(user)
    end

    def admin_user?(user)
      user.role.to_s == "admin" ||
        user.role.to_s == "super_admin" ||
        (user.respond_to?(:admin?) && user.admin?)
    end
  end
end