require 'net/http'

class MoviesController < ApplicationController

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
      .flat_map { |s| JSON.parse(s.recommendations_data) rescue [] }
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

    if @session_record.completed?
      redirect_to movie_session_path(@session_record) and return
    end
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
end
