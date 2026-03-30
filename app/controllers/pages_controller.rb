class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]
  def home
    @popular_movies = Rails.cache.fetch("trending_movies", expires_in: 1.hour) do
      api_key = ENV.fetch('TMDB_API_KEY', nil)
      url = URI("https://api.themoviedb.org/3/movie/popular?api_key=#{api_key}&language=pt-BR&page=1")
      response = Net::HTTP.get(url)
      data = JSON.parse(response)
      data["results"].first(20).sample(3).map { |m| m["title"].gsub(",", "") }
    end
  rescue => e
    Rails.logger.error "Erro ao buscar filmes: #{e.message}"
    @popular_movies = []
  end

  def profile
  end

  def update_profile
    platforms = params[:streaming_platforms] || []
    avatar = params.dig(:user, :avatar)
    display_name = params.dig(:user, :display_name)

    attrs = { streaming_platforms: platforms.reject(&:blank?) }
    attrs[:avatar] = avatar if avatar.present?
    attrs[:display_name] = display_name if display_name.present?

    current_user.update(attrs)
    render json: { success: true }
  end
end
