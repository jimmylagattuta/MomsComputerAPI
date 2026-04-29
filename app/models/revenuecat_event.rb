class RevenuecatEvent < ApplicationRecord
  belongs_to :user, optional: true

  has_one :subscription_transaction, dependent: :nullify
end