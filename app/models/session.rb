# app/models/session.rb
class Session < ApplicationRecord
  belongs_to :user


  enum :status, { processing: 0, completed: 1, failed: 2 }, default: :processing

  has_many :likes, dependent: :destroy
  has_many :movies, through: :likes

  # Atributos JSON
  attribute :recommendations_data, :json
  attribute :input_movies, :json

  def recommended_movies
    likes.where(suggestion: true).includes(:movie).map(&:movie)
  end

  def input_movies_list
    likes.where(suggestion: false).includes(:movie).map(&:movie)
  end

  def recommendations
    data = recommendations_data
    return data if data.is_a?(Array)
    return JSON.parse(data) if data.is_a?(String)
    []
  rescue JSON::ParserError
    []
  end

  # NOVO MÉTODO - POSICIONADO CORRETAMENTE (fora do rescue)
  def random_recommendation
    recommended_movies.first(3).shuffle.first
  end
end
