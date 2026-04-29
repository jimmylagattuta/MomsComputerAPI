class SubscriptionTransaction < ApplicationRecord
  belongs_to :user
  belongs_to :subscription, optional: true
  belongs_to :revenuecat_event, optional: true
end