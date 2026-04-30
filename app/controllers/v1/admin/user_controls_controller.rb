module V1
  module Admin
    class UserControlsController < ApplicationController
      include JwtAuth

      DEFAULT_MONTHLY_CALL_ALLOWANCE = 3

      before_action :authenticate_user!
      before_action :require_admin!
      before_action :set_user

      def show
        render json: control_center_payload
      end

      def update_calls
        call_cycle = current_or_create_call_cycle_for(@user)

        case params[:action_type]
        when "grant_extra_call"
          call_cycle.update!(calls_allowed: call_cycle.calls_allowed.to_i + 1)

        when "reset_calls_used"
          call_cycle.update!(calls_used: 0)

        when "set_monthly_limit"
          calls_allowed = params[:calls_allowed].to_i

          if calls_allowed.negative?
            return render json: { error: "calls_allowed must be 0 or greater" }, status: :unprocessable_entity
          end

          call_cycle.update!(calls_allowed: calls_allowed)

        else
          return render json: { error: "Invalid action_type" }, status: :unprocessable_entity
        end

        render json: {
          message: "Call controls updated",
          user: serialize_user(@user),
          current_call_cycle: serialize_real_call_cycle(call_cycle)
        }
      end

      def update_account
        render json: {
          message: "Account controls are not wired yet",
          user: serialize_user(@user)
        }, status: :not_implemented
      end

      def update_messaging
        render json: {
          message: "Messaging controls are not wired yet",
          user: serialize_user(@user)
        }, status: :not_implemented
      end

      def update_access
        render json: {
          message: "Access controls are not wired yet",
          user: serialize_user(@user)
        }, status: :not_implemented
      end

      def update_security
        render json: {
          message: "Security controls are not wired yet",
          user: serialize_user(@user)
        }, status: :not_implemented
      end

      private

      def set_user
        @user = User.find(params[:id])
      end

      def require_admin!
        return if current_user&.admin?

        render json: { error: "Admin access required" }, status: :forbidden
      end

      def control_center_payload
        real_call_cycle = current_call_cycle_for(@user)

        {
          user: serialize_user(@user),
          current_call_cycle: serialize_call_cycle_for_display(real_call_cycle),
          controls: {
            calls: {
              enabled: true,
              actions: [
                "grant_extra_call",
                "reset_calls_used",
                "set_monthly_limit"
              ]
            },
            account: {
              enabled: false,
              message: "Coming next"
            },
            messaging: {
              enabled: false,
              message: "Coming next"
            },
            access: {
              enabled: false,
              message: "Coming next"
            },
            security: {
              enabled: false,
              message: "Coming next"
            }
          }
        }
      end

      def current_call_cycle_for(user)
        user.support_call_cycles
            .where("cycle_start_at <= ? AND cycle_end_at >= ?", Time.current, Time.current)
            .order(cycle_start_at: :desc)
            .first
      end

      def current_or_create_call_cycle_for(user)
        current_call_cycle_for(user) ||
          user.support_call_cycles.create!(
            calls_allowed: DEFAULT_MONTHLY_CALL_ALLOWANCE,
            calls_used: 0,
            cycle_start_at: Time.current.beginning_of_month,
            cycle_end_at: Time.current.end_of_month
          )
      end

      def serialize_user(user)
        {
          id: user.id,
          email: user.email,
          first_name: user.try(:first_name),
          last_name: user.try(:last_name),
          phone: user.try(:phone),
          role: user.try(:role),
          status: user.try(:status),
          admin: user.admin?,
          created_at: user.created_at,
          updated_at: user.updated_at
        }
      end

      def serialize_call_cycle_for_display(call_cycle)
        if call_cycle.present?
          serialize_real_call_cycle(call_cycle)
        else
          serialize_virtual_default_call_cycle
        end
      end

      def serialize_real_call_cycle(call_cycle)
        allowed = call_cycle.calls_allowed.to_i
        used = call_cycle.calls_used.to_i

        {
          id: call_cycle.id,
          calls_allowed: allowed,
          calls_used: used,
          calls_remaining: [allowed - used, 0].max,
          cycle_start_at: call_cycle.cycle_start_at,
          cycle_end_at: call_cycle.cycle_end_at,
          virtual: false,
          status: "started",
          created_at: call_cycle.created_at,
          updated_at: call_cycle.updated_at
        }
      end

      def serialize_virtual_default_call_cycle
        allowed = DEFAULT_MONTHLY_CALL_ALLOWANCE
        used = 0

        {
          id: nil,
          calls_allowed: allowed,
          calls_used: used,
          calls_remaining: allowed,
          cycle_start_at: Time.current.beginning_of_month,
          cycle_end_at: Time.current.end_of_month,
          virtual: true,
          status: "not_started",
          created_at: nil,
          updated_at: nil
        }
      end
    end
  end
end