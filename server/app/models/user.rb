class User < ApplicationRecord
  has_many :sessions, dependent: :destroy

  normalizes :email, with: ->(e) { e.strip.downcase }
end
