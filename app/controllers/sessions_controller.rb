class SessionsController < ApplicationController
  def index
    @sessions = current_user.sessions.order(created_at: :desc)
    @visible_sessions = @sessions.first(3)
    @hidden_sessions = @sessions.drop(3)
  end

  def show
    @session_record = current_user.sessions.find(params[:id])
    @analysis = @session_record.analysis
    @recommendations = @session_record.recommendations || []
    @user_movies = @session_record.likes.where(suggestion: false).includes(:movie).map(&:movie)
    @suggested_movies = @session_record.likes.where(suggestion: true).includes(:movie).map(&:movie)
  end

  # app/controllers/sessions_controller.rb
  def random_movie
    @session_record = current_user.sessions.find(params[:id])

    # Pega as recomendações diretamente do session_record
    recommendations = @session_record.recommendations || []

    if recommendations.any?
      # Escolhe uma recomendação aleatória
      random_rec = recommendations.sample

      # Pega o tmdb_id da recomendação (que é um hash)
      tmdb_id = random_rec.dig("tmdb", "tmdb_id")

      Rails.logger.info "=" * 60
      Rails.logger.info "Roleta Russa - Recomendação sorteada:"
      Rails.logger.info "  TMDB ID: #{tmdb_id}"
      Rails.logger.info "  Título: #{random_rec['title']}"
      Rails.logger.info "  Session ID: #{@session_record.id}"
      Rails.logger.info "=" * 60

      if tmdb_id
        redirect_to movie_session_movie_path(@session_record, tmdb_id)
      else
        redirect_to movie_session_path(@session_record), alert: "Filme sem TMDB ID disponível"
      end
    else
      redirect_to movie_session_path(@session_record), alert: "Nenhuma recomendação disponível para sortear"
    end
  end

  # app/controllers/sessions_controller
  def new
  end
end
