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

    # Chamada para o Pipeline (usando os títulos selecionados)
    if params[:exclude].present?
      exclude = params[:exclude].split(",").map(&:strip)
      result = RecommendationPipeline.new(@movie_titles, current_user, exclude).call
    else
      cache_key = "recommendations/#{@movie_titles.sort.join('|')}"
      result = Rails.cache.fetch(cache_key, expires_in: 30.days) do
        RecommendationPipeline.new(@movie_titles, current_user).call
      end
    end

    session_record = current_user.sessions.create!(
      analysis: result[:analysis],
      recommendations_data: result[:recommendations].to_json
    )

    # 3. Criamos ou encontramos os filmes que o usuário selecionou para registrar os Likes
    @movie_titles.each do |title|
      movie = Movie.find_or_create_by!(title: title)
      session_record.likes.create!(movie: movie, suggestion: false)
    end

    # 4. Registramos as sugestões da IA
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
