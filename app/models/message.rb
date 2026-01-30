# app/models/message.rb
class Message < ApplicationRecord
  belongs_to :conversation
  has_many :attachments, dependent: :destroy
  has_one :blocked_artifact, dependent: :destroy
  has_many_attached :images

  # If you want ActiveStorage:
  # has_many_attached :files  (but I prefer Attachment model + has_one_attached there)
end