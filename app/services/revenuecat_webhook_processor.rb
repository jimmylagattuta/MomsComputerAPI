class RevenuecatWebhookProcessor
  REVENUE_EVENT_TYPES = [
    "INITIAL_PURCHASE",
    "RENEWAL",
    "NON_RENEWING_PURCHASE"
  ].freeze

  ACTIVE_EVENT_TYPES = [
    "INITIAL_PURCHASE",
    "RENEWAL",
    "UNCANCELLATION",
    "NON_RENEWING_PURCHASE"
  ].freeze

  CANCEL_EVENT_TYPES = [
    "CANCELLATION"
  ].freeze

  BILLING_ISSUE_EVENT_TYPES = [
    "BILLING_ISSUE"
  ].freeze

  EXPIRATION_EVENT_TYPES = [
    "EXPIRATION"
  ].freeze

  attr_reader :payload, :event

  def initialize(payload:, event:)
    @payload = payload || {}
    @event = event || {}
  end

  def call
    ActiveRecord::Base.transaction do
      revenuecat_event = create_revenuecat_event!
      customer_link = upsert_customer_link!
      user = revenuecat_event.user || customer_link&.user

      if user && revenuecat_event.user_id.blank?
        revenuecat_event.update!(user: user)
      end

      return revenuecat_event unless user

      subscription = upsert_subscription!(user, revenuecat_event)
      create_subscription_transaction!(user, subscription, revenuecat_event)
      upsert_entitlement!(user, revenuecat_event)

      revenuecat_event
    end
  end

  private

  def create_revenuecat_event!
    revenuecat_event = RevenuecatEvent.find_or_initialize_by(event_id: event_id)

    revenuecat_event.assign_attributes(
      user: revenuecat_event.user || find_user,
      event_type: event_type,
      app_user_id: app_user_id,
      product_id: product_id,
      entitlement_key: entitlement_key,
      transaction_id: transaction_id,
      original_transaction_id: original_transaction_id,
      store: store,
      environment: environment,
      price_cents: price_cents,
      currency: currency,
      purchased_at: purchased_at,
      expiration_at: expiration_at,
      raw_payload: payload
    )

    revenuecat_event.save!
    revenuecat_event
  end

  def upsert_customer_link!
    return nil if app_user_id.blank?

    link = RevenuecatCustomerLink.find_or_initialize_by(app_user_id: app_user_id)

    resolved_user = find_user

    link.assign_attributes(
      user: resolved_user || link.user,
      original_app_user_id: revenuecat_original_app_user_id.presence || link.original_app_user_id,
      status: customer_link_status(resolved_user || link.user),
      last_event_id: event_id,
      last_event_type: event_type,
      product_id: product_id,
      entitlement_key: entitlement_key,
      store: store,
      environment: environment,
      expiration_at: expiration_at
    )

    link.save!
    link
  end

  def customer_link_status(user)
    base =
      if active_event? || cancel_event?
        "active"
      elsif billing_issue_event?
        "billing_issue"
      elsif expiration_event?
        "expired"
      else
        "unknown"
      end

    user.present? ? "linked_#{base}" : "anonymous_#{base}"
  end

  def upsert_subscription!(user, revenuecat_event)
    subscription = find_subscription(user)

    subscription.assign_attributes(
      user: user,
      plan: find_plan,
      provider: "revenuecat",
      provider_subscription_id: original_transaction_id.presence || transaction_id,
      status: subscription_status,
      revenuecat_app_user_id: app_user_id,
      revenuecat_original_app_user_id: revenuecat_original_app_user_id,
      product_id: product_id,
      entitlement_key: entitlement_key,
      store: store,
      environment: environment,
      transaction_id: transaction_id,
      original_transaction_id: original_transaction_id,
      price_cents: price_cents,
      currency: currency,
      billing_period: billing_period,
      current_period_start: purchased_at,
      current_period_end: expiration_at,
      cancel_at_period_end: cancel_at_period_end?,
      cancelled_at: cancelled_at_value,
      billing_issue_at: billing_issue_at_value,
      expired_at: expired_at_value,
      last_validated_at: Time.current
    )

    subscription.save!
    subscription
  end

  def create_subscription_transaction!(user, subscription, revenuecat_event)
    return unless revenue_event?
    return if transaction_id.blank?
    return if SubscriptionTransaction.exists?(transaction_id: transaction_id)

    SubscriptionTransaction.create!(
      user: user,
      subscription: subscription,
      revenuecat_event: revenuecat_event,
      provider: "revenuecat",
      event_type: event_type,
      product_id: product_id,
      entitlement_key: entitlement_key,
      transaction_id: transaction_id,
      original_transaction_id: original_transaction_id,
      store: store,
      environment: environment,
      price_cents: price_cents,
      currency: currency,
      purchased_at: purchased_at
    )
  end

  def upsert_entitlement!(user, revenuecat_event)
    key = entitlement_key.presence || "premium"

    entitlement = Entitlement.find_or_initialize_by(
      user: user,
      key: key,
      source: "revenuecat"
    )

    entitlement.enabled = entitlement_enabled?
    entitlement.expires_at = expiration_at
    entitlement.save!

    entitlement
  end

  def find_user
    return nil if app_user_id.blank?

    # Signed-in RevenueCat users use our Rails User.id as app_user_id.
    if app_user_id.to_s.match?(/\A\d+\z/)
      user = User.find_by(id: app_user_id)
      return user if user
    end

    # Anonymous RevenueCat users can be linked later.
    link =
      RevenuecatCustomerLink.find_by(app_user_id: app_user_id) ||
      RevenuecatCustomerLink.find_by(original_app_user_id: revenuecat_original_app_user_id)

    link&.user
  end

  def find_plan
    Plan.find_by(provider_product_id: product_id) || Plan.first
  end

  def find_subscription(user)
    Subscription.find_or_initialize_by(
      user: user,
      provider: "revenuecat",
      original_transaction_id: original_transaction_id.presence
    )
  rescue ActiveRecord::StatementInvalid
    Subscription.find_or_initialize_by(
      user: user,
      provider: "revenuecat",
      product_id: product_id
    )
  end

  def event_id
    event["id"].presence ||
      event["event_id"].presence ||
      payload["id"].presence ||
      SecureRandom.uuid
  end

  def event_type
    event["type"].presence || event["event_type"].presence
  end

  def app_user_id
    event["app_user_id"].presence || event["appUserId"].presence
  end

  def revenuecat_original_app_user_id
    event["original_app_user_id"].presence || event["originalAppUserId"].presence
  end

  def product_id
    event["product_id"].presence || event["productId"].presence
  end

  def entitlement_key
    event["entitlement_id"].presence ||
      event["entitlement_key"].presence ||
      event["entitlementKey"].presence ||
      "premium"
  end

  def transaction_id
    event["transaction_id"].presence || event["transactionId"].presence
  end

  def original_transaction_id
    event["original_transaction_id"].presence || event["originalTransactionId"].presence
  end

  def store
    event["store"].presence
  end

  def environment
    event["environment"].presence
  end

  def currency
    event["currency"].presence ||
      event["price_currency"].presence ||
      event["currency_code"].presence
  end

  def price_cents
    cents =
      event["price_in_purchased_currency_cents"].presence ||
      event["price_cents"].presence

    return cents.to_i if cents.present?

    price =
      event["price_in_purchased_currency"].presence ||
      event["price"].presence

    return nil if price.blank?

    (price.to_d * 100).round
  end

  def purchased_at
    timestamp_from_event(
      "purchased_at_ms",
      "purchased_at",
      "purchase_date_ms",
      "purchase_date"
    )
  end

  def expiration_at
    timestamp_from_event(
      "expiration_at_ms",
      "expiration_at",
      "expires_at_ms",
      "expires_at"
    )
  end

  def billing_period
    return "yearly" if product_id.to_s.downcase.include?("year")
    return "monthly" if product_id.to_s.downcase.include?("month")

    nil
  end

  def subscription_status
    if active_event?
      "active"
    elsif cancel_event?
      "cancelled"
    elsif billing_issue_event?
      "billing_issue"
    elsif expiration_event?
      "expired"
    else
      "unknown"
    end
  end

  def cancel_at_period_end?
    cancel_event?
  end

  def cancelled_at_value
    cancel_event? ? Time.current : nil
  end

  def billing_issue_at_value
    billing_issue_event? ? Time.current : nil
  end

  def expired_at_value
    expiration_event? ? Time.current : nil
  end

  def entitlement_enabled?
    active_event? || cancel_event?
  end

  def revenue_event?
    REVENUE_EVENT_TYPES.include?(event_type)
  end

  def active_event?
    ACTIVE_EVENT_TYPES.include?(event_type)
  end

  def cancel_event?
    CANCEL_EVENT_TYPES.include?(event_type)
  end

  def billing_issue_event?
    BILLING_ISSUE_EVENT_TYPES.include?(event_type)
  end

  def expiration_event?
    EXPIRATION_EVENT_TYPES.include?(event_type)
  end

  def timestamp_from_event(*keys)
    keys.each do |key|
      value = event[key]
      next if value.blank?

      return Time.at(value.to_i / 1000.0) if key.end_with?("_ms")
      return Time.zone.parse(value.to_s)
    rescue ArgumentError, TypeError
      next
    end

    nil
  end
end