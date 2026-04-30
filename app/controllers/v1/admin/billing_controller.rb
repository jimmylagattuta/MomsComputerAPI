class V1::Admin::BillingController < ApplicationController
  include JwtAuth

  before_action :authenticate_user!
  before_action :require_admin!

  def kpis
    now = Time.current
    start_of_month = now.beginning_of_month
    start_of_year = now.beginning_of_year

    transactions = SubscriptionTransaction.all
    subscriptions = Subscription.all

    monthly_transactions = transactions.where("purchased_at >= ?", start_of_month)
    yearly_transactions = transactions.where("purchased_at >= ?", start_of_year)

    revenue_this_month_cents = monthly_transactions.sum(:price_cents)
    revenue_this_year_cents = yearly_transactions.sum(:price_cents)
    total_revenue_cents = transactions.sum(:price_cents)

    active_subscribers = subscriptions
      .where(status: "active")
      .count

    billing_issue_subscribers = subscriptions
      .where(status: "billing_issue")
      .count

    cancelled_subscribers = subscriptions
      .where(status: "cancelled")
      .count

    expired_subscribers = subscriptions
      .where(status: "expired")
      .count

    paying_users = transactions
      .where.not(user_id: nil)
      .distinct
      .count(:user_id)

    monthly_active_revenue_cents = active_subscription_count_for_period("monthly") * 999
    yearly_active_revenue_cents = active_subscription_count_for_period("yearly") * 9999

    mrr_cents = monthly_active_revenue_cents + (yearly_active_revenue_cents / 12.0)

    if mrr_cents.zero? && revenue_this_month_cents.positive?
      mrr_cents = revenue_this_month_cents
    end

    revenue_by_platform_this_month = revenue_by_platform_for(monthly_transactions)
    revenue_by_platform_this_year = revenue_by_platform_for(yearly_transactions)
    revenue_by_platform = revenue_by_platform_for(transactions)

    subscribers_by_platform = subscribers_by_platform_for(subscriptions)
    active_subscribers_by_platform = subscribers_by_platform_for(
      subscriptions.where(status: "active")
    )

    revenue_by_product = transactions
      .group(:product_id)
      .sum(:price_cents)
      .transform_keys { |key| key.presence || "UNKNOWN" }
      .transform_values(&:to_i)

    revenue_by_product_this_month = monthly_transactions
      .group(:product_id)
      .sum(:price_cents)
      .transform_keys { |key| key.presence || "UNKNOWN" }
      .transform_values(&:to_i)

    revenue_by_product_this_year = yearly_transactions
      .group(:product_id)
      .sum(:price_cents)
      .transform_keys { |key| key.presence || "UNKNOWN" }
      .transform_values(&:to_i)

    render json: {
      mrr_cents: mrr_cents.round,
      revenue_this_month_cents: revenue_this_month_cents.to_i,
      revenue_this_year_cents: revenue_this_year_cents.to_i,
      total_revenue_cents: total_revenue_cents.to_i,

      active_subscribers: active_subscribers,
      billing_issue_subscribers: billing_issue_subscribers,
      cancelled_subscribers: cancelled_subscribers,
      expired_subscribers: expired_subscribers,
      total_users: User.count,
      paying_users: paying_users,

      revenue_by_platform_this_month: revenue_by_platform_this_month,
      revenue_by_platform_this_year: revenue_by_platform_this_year,
      revenue_by_platform: revenue_by_platform,

      subscribers_by_platform: subscribers_by_platform,
      active_subscribers_by_platform: active_subscribers_by_platform,

      revenue_by_product_this_month: revenue_by_product_this_month,
      revenue_by_product_this_year: revenue_by_product_this_year,
      revenue_by_product: revenue_by_product
    }, status: :ok
  end

  def recent_events
    events = RevenuecatEvent
      .order(created_at: :desc)
      .limit(25)

    render json: {
      events: events.map { |event| serialize_revenuecat_event(event) },
      meta: {
        count: events.length,
        generated_at: Time.current.iso8601
      }
    }, status: :ok
  end

  def recent_transactions
    transactions = SubscriptionTransaction
      .includes(:user)
      .order(purchased_at: :desc)
      .limit(25)

    render json: {
      transactions: transactions.map { |transaction| serialize_transaction(transaction) },
      meta: {
        count: transactions.length,
        generated_at: Time.current.iso8601
      }
    }, status: :ok
  end

  def subscribers
    subscriptions = Subscription
      .includes(:user)
      .order(updated_at: :desc)
      .limit(100)

    render json: {
      subscribers: subscriptions.map { |subscription| serialize_subscription(subscription) },
      meta: {
        count: subscriptions.length,
        generated_at: Time.current.iso8601
      }
    }, status: :ok
  end

  private

  def require_admin!
    unless current_user&.role == "admin"
      render json: { error: "admin_required" }, status: :forbidden
    end
  end

  def active_subscription_count_for_period(period)
    normalized_period = period.to_s.downcase

    Subscription
      .where(status: "active")
      .where(
        "#{case_insensitive_like_sql('product_id')} OR #{case_insensitive_like_sql('billing_period')}",
        "%#{normalized_period}%",
        "%#{normalized_period}%"
      )
      .count
  end

  def revenue_by_platform_for(scope)
    scope
      .group(:store)
      .sum(:price_cents)
      .transform_keys { |key| normalize_store_key(key) }
      .transform_values(&:to_i)
  end

  def subscribers_by_platform_for(scope)
    scope
      .group(:store)
      .count
      .transform_keys { |key| normalize_store_key(key) }
      .transform_values(&:to_i)
  end

  def normalize_store_key(value)
    normalized_value = value.to_s.strip.upcase

    return "UNKNOWN" if normalized_value.blank?

    case normalized_value
    when "APP_STORE", "APPLE", "IOS", "APPSTORE", "APP-STORE"
      "APP_STORE"
    when "PLAY_STORE", "GOOGLE_PLAY", "ANDROID", "GOOGLE", "PLAYSTORE", "PLAY-STORE"
      "PLAY_STORE"
    else
      normalized_value
    end
  end

  def case_insensitive_like_sql(column_name)
    "LOWER(COALESCE(#{column_name}, '')) LIKE ?"
  end

  def money_hash(cents)
    cents = cents.to_f

    {
      cents: cents.round,
      dollars: (cents / 100.0).round(2),
      formatted: "$#{format('%.2f', cents / 100.0)}"
    }
  end

  def serialize_revenuecat_event(event)
    {
      id: event.id,
      user_id: safe_read(event, :user_id),
      event_id: safe_read(event, :event_id),
      event_type: safe_read(event, :event_type),
      app_user_id: safe_read(event, :app_user_id),
      product_id: safe_read(event, :product_id),
      entitlement_key: safe_read(event, :entitlement_key),
      transaction_id: safe_read(event, :transaction_id),
      original_transaction_id: safe_read(event, :original_transaction_id),
      store: safe_read(event, :store),
      environment: safe_read(event, :environment),
      price: money_hash(safe_read(event, :price_cents).to_i),
      currency: safe_read(event, :currency) || "USD",
      purchased_at: format_time(safe_read(event, :purchased_at)),
      expiration_at: format_time(safe_read(event, :expiration_at)),
      created_at: format_time(event.created_at)
    }
  end

  def serialize_transaction(transaction)
    user = safe_read(transaction, :user)

    {
      id: transaction.id,
      user: serialize_user_summary(user),
      user_id: safe_read(transaction, :user_id),
      subscription_id: safe_read(transaction, :subscription_id),
      revenuecat_event_id: safe_read(transaction, :revenuecat_event_id),
      provider: safe_read(transaction, :provider),
      event_type: safe_read(transaction, :event_type),
      product_id: safe_read(transaction, :product_id),
      entitlement_key: safe_read(transaction, :entitlement_key),
      transaction_id: safe_read(transaction, :transaction_id),
      original_transaction_id: safe_read(transaction, :original_transaction_id),
      store: safe_read(transaction, :store),
      environment: safe_read(transaction, :environment),
      price: money_hash(safe_read(transaction, :price_cents).to_i),
      currency: safe_read(transaction, :currency) || "USD",
      purchased_at: format_time(safe_read(transaction, :purchased_at)),
      created_at: format_time(transaction.created_at)
    }
  end

  def serialize_subscription(subscription)
    user = safe_read(subscription, :user)

    {
      id: subscription.id,
      user: serialize_user_summary(user),
      user_id: safe_read(subscription, :user_id),
      plan_id: safe_read(subscription, :plan_id),
      provider: safe_read(subscription, :provider),
      provider_subscription_id: safe_read(subscription, :provider_subscription_id),
      status: safe_read(subscription, :status),
      revenuecat_app_user_id: safe_read(subscription, :revenuecat_app_user_id),
      revenuecat_original_app_user_id: safe_read(subscription, :revenuecat_original_app_user_id),
      product_id: safe_read(subscription, :product_id),
      entitlement_key: safe_read(subscription, :entitlement_key),
      store: safe_read(subscription, :store),
      environment: safe_read(subscription, :environment),
      transaction_id: safe_read(subscription, :transaction_id),
      original_transaction_id: safe_read(subscription, :original_transaction_id),
      price: money_hash(safe_read(subscription, :price_cents).to_i),
      currency: safe_read(subscription, :currency) || "USD",
      billing_period: safe_read(subscription, :billing_period),
      current_period_start: format_time(safe_read(subscription, :current_period_start)),
      current_period_end: format_time(safe_read(subscription, :current_period_end)),
      cancel_at_period_end: safe_read(subscription, :cancel_at_period_end),
      cancelled_at: format_time(safe_read(subscription, :cancelled_at)),
      billing_issue_at: format_time(safe_read(subscription, :billing_issue_at)),
      expired_at: format_time(safe_read(subscription, :expired_at)),
      last_validated_at: format_time(safe_read(subscription, :last_validated_at)),
      updated_at: format_time(subscription.updated_at),
      created_at: format_time(subscription.created_at)
    }
  end

  def serialize_user_summary(user)
    return nil unless user

    {
      id: user.id,
      name: user_name(user),
      email: safe_read(user, :email),
      phone: safe_read(user, :phone),
      role: safe_read(user, :role),
      status: safe_read(user, :status),
      created_at: format_time(user.created_at)
    }
  end

  def user_name(user)
    full_name = [
      safe_read(user, :first_name),
      safe_read(user, :last_name)
    ].compact.join(" ").strip

    return full_name if full_name.present?

    safe_read(user, :preferred_name)
  end

  def format_time(value)
    return nil unless value.respond_to?(:iso8601)

    value.iso8601
  end

  def safe_read(record, attribute)
    return nil unless record
    return nil unless record.respond_to?(attribute)

    record.public_send(attribute)
  end
end