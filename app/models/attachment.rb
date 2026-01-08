# app/models/attachment.rb
class Attachment < ApplicationRecord
  belongs_to :message
  has_one_attached :file
end