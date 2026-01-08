# app/models/conversation.rb
class Conversation < ApplicationRecord
  belongs_to :user
  has_many :messages, dependent: :destroy
  has_many :escalation_tickets, dependent: :nullify

  validates :channel, presence: true
end