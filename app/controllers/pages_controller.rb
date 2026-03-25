class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]
  def home
    api_key = ENV.fetch('TMDB_API_KEY', nil)
    url = URI("https://api.themoviedb.org/3/movie/popular?api_key=#{api_key}&language=pt-BR&page=1")
    response = Net::HTTP.get(url)
    data = JSON.parse(response)
    @popular_movies = data["results"].first(20).sample(3).map { |m| m["title"] }
  rescue
    @popular_movies = ["Um Sonho de Liberdade", "O Poderoso Chefão", "O Cavaleiro das Trevas", "O Senhor dos Anéis", "A Lista de Schindler"]
  end

  def profile
  end

  def update_profile
    platforms = params[:streaming_platforms] || []
    avatar = params.dig(:user, :avatar)

    attrs = { streaming_platforms: platforms.reject(&:blank?) }
    attrs[:avatar] = avatar if avatar.present?

    current_user.update(attrs)
    render json: { success: true }
  end
end
