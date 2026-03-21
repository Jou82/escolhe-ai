class MoviesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]

  def index
  end

  def show
  end

  def create
    @movies = params[:movies].split(/,|(?:\se\s)/).map(&:strip).reject(&:blank?)

    if @movies.length != 3
      flash[:alert] = "Por favor, digite exatamente 3 filmes separados por vírgula."
      return redirect_to root_path
    end

    result = RecommendationPipeline.new(@movies, current_user).call

    session_record = current_user.sessions.create!(
      analysis: result[:analysis],
      recommendations_data: result[:recommendations].to_json
    )

    @movies.each do |title|
      movie = Movie.find_or_create_by!(title: title)
      session_record.likes.create!(movie: movie, suggestion: false)
    end

    result[:recommendations].each do |rec|
      movie = Movie.find_or_create_by!(title: rec["title"]) do |m|
        m.release_year = rec["year"] || rec.dig("tmdb", :release_date)&.slice(0, 4)&.to_i
        m.synopsis = rec.dig("tmdb", :overview) || rec["reason"]
      end

      if rec["genres"].present?
        rec["genres"].each do |genre_name|
          genre = Genre.find_or_create_by!(name: genre_name)
          MovieGenre.find_or_create_by!(movie: movie, genre: genre)
        end
      end

      session_record.likes.create!(movie: movie, suggestion: true)
    end

    redirect_to session_path(session_record)

  rescue AnthropicService::RecommendationError => e
    flash[:alert] = "Erro ao gerar recomendações: #{e.message}"
    redirect_to root_path
  end
end
