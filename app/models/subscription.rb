class Subscription < ApplicationRecord
  belongs_to :user
  belongs_to :plan, optional: true

  has_many :subscription_transactions, dependent: :nullify
end