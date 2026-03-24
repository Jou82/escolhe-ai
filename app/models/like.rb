class Like < ApplicationRecord
  belongs_to :movie
  belongs_to :session
  validates :movie, presence: true
end
