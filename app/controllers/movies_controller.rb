require 'net/http'

class MoviesController < ApplicationController
  # before_action :check_rate_limit, only: [:create]

  def index
  end

  def search
    query = params[:q].to_s.strip
    api_key = ENV.fetch('TMDB_API_KEY', nil)

    if query.present?
      url = URI("https://api.themoviedb.org/3/search/movie?api_key=#{api_key}&query=#{ERB::Util.url_encode(query)}&language=pt-BR")

      begin
        response = Net::HTTP.get(url)
        data = JSON.parse(response)

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
    # Rate limit já verificado no before_action
    if params[:movies].is_a?(Array)
      @movie_titles = params[:movies].reject(&:blank?)
    else
      @movie_titles = params[:movies].to_s.split(',').map(&:strip).reject(&:blank?)
    end

    if @movie_titles.length != 3
      flash[:alert] = "Por favor, selecione 3 filmes válidos."
      return redirect_to root_path
    end

    previous_recommendations = current_user.sessions
                                           .where(status: 1)
                                           .where.not(recommendations_data: nil)
                                           .flat_map do |s|
      JSON.parse(s.recommendations_data)
    rescue StandardError
      []
    end
                                           .map { |rec| rec["title"] }
                                           .uniq

    Rails.logger.info "📚 Filmes já recomendados: #{previous_recommendations.join(', ')}"

    session_record = current_user.sessions.create!(
      input_movies: @movie_titles,
      status: 0
    )

    GenerateRecommendationsJob.perform_later(
      current_user.id,
      @movie_titles,
      previous_recommendations,
      session_record.id
    )

    redirect_to processing_movies_path(id: session_record.id)
  end

  def processing
    @session_record = current_user.sessions.find(params[:id])

    return unless @session_record.completed?

    redirect_to movie_session_path(@session_record) and return
  end

  def check_status
    session_record = current_user.sessions.select(:id, :status, :error_message).find_by(id: params[:id])

    return render json: { status: "not_found" }, status: :not_found unless session_record

    if session_record.completed?
      render json: { status: "completed", url: movie_session_path(session_record) }
    elsif session_record.failed?
      render json: { status: "failed", error: session_record.error_message }
    else
      render json: { status: "processing" }
    end
  end

  # private

  # def check_rate_limit
  #   cache_key = "rate_limit:create_movies:user:#{current_user.id}"

  #   busca_count = Rails.cache.read(cache_key).to_i

  #   if busca_count >= 3
  #     render_rate_limit_error
  #     return false
  #   else
  #     Rails.cache.write(cache_key, busca_count + 1, expires_in: 24.hours)
  #   end
  # end

  # def render_rate_limit_error
  #   render html: rate_limit_page.html_safe, status: 429
  # end

# def rate_limit_page
  <<~HTML
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Limite atingido - Escolhe AI</title>
      <link rel="stylesheet" href="/assets/rate_limit.css">
      </head>
      <body class="rate-limit-page">
        <div class="hero-bg">
          <div class="orb orb-1"></div>
          <div class="orb orb-2"></div>
          <div class="orb orb-3"></div>
        </div>

        <div class="content">
          <div class="card">
            <div class="logo">
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <rect x="2" y="7" width="20" height="15" rx="2" ry="2"></rect><polyline points="17 2 12 7 7 2"></polyline>
              </svg>
              <span>Escolhe AI</span>
            </div>

            <h1>
              Chega de buscas<br>
              <span>por hoje.</span>
            </h1>

            <div class="count-badge">
              <strong>3/3</strong> buscas realizadas
            </div>

            <p class="message">
              Você já usou suas <strong>3 buscas diárias</strong>.<br>
              Volte amanhã para descobrir novos filmes!
            </p>

            <a href="/" class="btn-back">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                <line x1="5" y1="12" x2="19" y2="12"></line>
                <polyline points="12 5 19 12 12 19"></polyline>
              </svg>
              Voltar ao início
            </a>

            <div class="trending">
              <span class="trending-tag">Avatar</span>
              <span class="trending-tag">Fogo e Cinzas</span>
              <span class="trending-tag">Caminhos do Crime</span>
              <span class="trending-tag">Socorro!</span>
            </div>
          </div>
        </body>
      </html>
    HTML
  # end
end
