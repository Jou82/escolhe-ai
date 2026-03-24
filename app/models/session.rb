class Session < ApplicationRecord
  belongs_to :user
  has_many :likes

  enum :status, { processing: 0, completed: 1, failed: 2 }
end
