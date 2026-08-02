class MoviesController < ApplicationController
  before_action :check_rate_limit, only: [:create]

  def index
  end

  def search
    render json: MovieSearchService.call(params[:q])
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
    @movie_inputs = parse_movie_inputs

    if @movie_inputs.length != 3
      flash[:alert] = "Por favor, selecione 3 filmes válidos."
      return redirect_to root_path
    end

    @movie_titles = @movie_inputs.map { |m| m[:title] }

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
      input_movies: @movie_inputs.map { |m| m.stringify_keys },
      status: 0
    )

    GenerateRecommendationsJob.perform_later(
      current_user.id,
      @movie_inputs.map { |m| m.stringify_keys },
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
    session_record = current_user.sessions.find_by(id: params[:id])

    return render json: { status: "not_found" }, status: :not_found unless session_record

    # Jobs that never ran leave status=processing forever; surface as failed
    # so the UI can stop polling (common when Solid Queue worker was down).
    if session_record.processing? && session_record.created_at < 3.minutes.ago
      session_record.update!(
        status: :failed,
        error_message: session_record.error_message.presence ||
          "A geração demorou demais ou o worker de jobs não está a correr. Tente novamente."
      )
    end

    if session_record.completed?
      render json: { status: "completed", url: movie_session_path(session_record) }
    elsif session_record.failed?
      render json: { status: "failed", error: session_record.error_message }
    else
      render json: { status: "processing" }
    end
  end

  private

  # Accepts either:
  # - movies[] + tmdb_ids[] + years[] from the chip UI
  # - legacy comma-separated movies string
  def parse_movie_inputs
    if params[:movies].is_a?(Array)
      titles = params[:movies].map { |t| t.to_s.strip }.reject(&:blank?)
      ids = Array(params[:tmdb_ids]).map { |id| id.to_s.strip.presence }
      years = Array(params[:years]).map { |y| y.to_s.strip.presence }

      titles.each_with_index.map do |title, index|
        {
          title: title,
          tmdb_id: ids[index]&.to_i&.positive? ? ids[index].to_i : nil,
          year: years[index]
        }
      end
    else
      params[:movies].to_s.split(",").map(&:strip).reject(&:blank?).map do |title|
        { title: title, tmdb_id: nil, year: nil }
      end
    end
  end

  def check_rate_limit
    # Only completed searches count. Stuck "processing" sessions (e.g. when
    # Solid Queue was not running) must not burn the daily quota, and failed
    # attempts are already excluded.
    count = current_user.sessions
                        .where("created_at >= ?", 24.hours.ago)
                        .where(status: Session.statuses[:completed])
                        .count

    if count >= 3
      render_rate_limit_error
      return false
    end
  end

  def render_rate_limit_error
    render html: rate_limit_page.html_safe, status: 429
  end

  def rate_limit_page
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
            </div>
          </div>
        </body>
      </html>
    HTML
  end
end
