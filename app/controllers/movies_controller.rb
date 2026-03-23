class MoviesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]

  def index
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
  @movies = params[:movies].split(/,|(?:\se\s)/).map(&:strip).reject(&:blank?)

  if @movies.length != 3
    flash[:alert] = "Por favor, digite exatamente 3 filmes separados por vírgula."
    return redirect_to root_path
  end

  # ALTERAÇÃO: Busca recomendações anteriores para evitar repetição
  previous_recommendations = current_user.sessions
    .where(status: 1)
    .where.not(recommendations_data: nil)
    .flat_map { |s| JSON.parse(s.recommendations_data) rescue [] }
    .map { |rec| rec["title"] }
    .uniq

  Rails.logger.info "📚 Filmes já recomendados: #{previous_recommendations.join(', ')}"

  # Cria a sessão com status "processing" (0)
  session_record = current_user.sessions.create!(
    input_movies: @movies,
    status: 0,
    analysis: nil,
    recommendations_data: nil
  )

  # Enfileira o job com os filmes a serem excluídos
  GenerateRecommendationsJob.perform_later(
    current_user.id,
    @movies,
    previous_recommendations,  # ALTERAÇÃO: passa filmes já recomendados
    session_record.id
  )

  redirect_to processing_movies_path(id: session_record.id)
end

  def processing
    @session = current_user.sessions.find(params[:id])

    # Se já estiver completo (status = 1), redireciona para os resultados
    if @session.status == 1
      redirect_to session_path(@session)
    end
    # Se não, mostra a página de processing
  end

  def check_status
    session = current_user.sessions.find(params[:id])
    render json: { status: session.status, completed: session.status == 1 }
  end
end
