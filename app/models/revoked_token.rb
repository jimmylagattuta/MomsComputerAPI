class RevokedToken < ApplicationRecord
  validates :jti, presence: true, uniqueness: true
  validates :expires_at, presence: true
end