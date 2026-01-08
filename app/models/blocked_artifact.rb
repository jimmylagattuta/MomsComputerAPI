# app/models/blocked_artifact.rb
class BlockedArtifact < ApplicationRecord
  belongs_to :message

  validates :reason, presence: true
end