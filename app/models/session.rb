# app/models/session.rb
class Session < ApplicationRecord
  belongs_to :user
  has_many :likes, dependent: :destroy
  has_many :movies, through: :likes

  # Atributos JSON
  attribute :recommendations_data, :json
  attribute :input_movies, :json

  # Status helpers (0=processing, 1=completed, 2=failed)
  def processing?
    status == 0
  end

  def completed?
    status == 1
  end

  def failed?
    status == 2
  end

  def recommended_movies
    likes.where(suggestion: true).includes(:movie).map(&:movie)
  end

  def input_movies_list
    likes.where(suggestion: false).includes(:movie).map(&:movie)
  end

  def recommendations
    return [] unless recommendations_data.is_a?(Array)
    recommendations_data
  end
end
