class Plan < ApplicationRecord
  has_many :subscriptions, dependent: :nullify
end