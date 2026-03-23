require 'net/http'

class MoviesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]

  def index
  end

  def search
    query = params[:q].to_s.strip
    api_key = ENV.fetch('TMDB_API_KEY', nil) # Certifique-se que o nome no .env é este

    if query.present?
      # 1. Buscamos na API externa (TMDB como exemplo)
      url = URI("https://api.themoviedb.org/3/search/movie?api_key=#{api_key}&query=#{ERB::Util.url_encode(query)}&language=pt-BR")

      begin
        response = Net::HTTP.get(url)
        data = JSON.parse(response)

        # 2. Mapeamos os resultados para o formato que o TomSelect espera
        # Note que enviamos o 'title' como valor principal
        @results = data["results"].map do |movie|
          {
            title: movie["title"],
            id: movie["id"],
            year: movie["release_date"]&.slice(0, 4)
          }
        end
      rescue StandardError => e
        Rails.logger.error "Erro na busca da API: #{e.message}"
        @results = []
      end
    else
      @results = []
    end

    render json: @results
  end

  def show
    @session_record = current_user.sessions.find(params[:session_id])
    @movie = Movie.find(params[:id])
    @genres = @movie.genres
    @like = Like.find_by(session: @session_record, movie: @movie)

    recommendations = JSON.parse(@session_record.recommendations_data || "[]")
    @rec_data = recommendations.find { |r| r["title"] == @movie.title }
  end

  def create
    # O TomSelect envia os títulos dos filmes no array params[:movies]
    if params[:movies].is_a?(Array)
      @movie_titles = params[:movies].reject(&:blank?)
    else
      @movie_titles = params[:movies].to_s.split(/,|(?:\se\s)/).map(&:strip).reject(&:blank?)
    end

    if @movie_titles.length != 3
      flash[:alert] = "Por favor, selecione 3 filmes válidos."
      return redirect_to root_path
    end

    exclude = params[:exclude].present? ? params[:exclude].split(",").map(&:strip) : []

    cache_key = "recommendations/#{@movies.sort.join('|')}"
    cached_result = Rails.cache.read(cache_key)

    if cached_result
      session_record = current_user.sessions.create!(
        analysis: cached_result[:analysis],
        recommendations_data: cached_result[:recommendations].to_json,
        input_movies: @movies,
        status: 1
      )

      @movies.each do |title|
        movie = Movie.find_or_create_by!(title: title)
        session_record.likes.create!(movie: movie, suggestion: false)
      end

      cached_result[:recommendations].each do |rec|
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
    else
      session_record = current_user.sessions.create!(
        input_movies: @movies,
        status: 0
      )

      GenerateRecommendationsJob.perform_later(
        current_user.id,
        @movies,
        exclude,
        session_record.id
      )

      # ÚNICA LINHA CORRIGIDA
      redirect_to processing_movies_path(id: session_record.id)
    end

  def check_status
    session = current_user.sessions.find(params[:id])
    render json: { status: session.status, completed: session.status == 1 }
  end

  def processing
    @session_record = current_user.sessions.find(params[:id])

    if @session_record.completed?
      redirect_to session_path(@session_record) and return
    end
  end

  def check_status
    session_record = current_user.sessions.find(params[:id])

    if session_record.completed?
      render json: { status: "completed", url: session_path(session_record) }
    elsif session_record.failed?
      render json: { status: "failed", error: session_record.error_message }
    else
      render json: { status: "processing" }
    end
  end
end
