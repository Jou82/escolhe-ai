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
    @analysis = result[:analysis]
    @recommendations = result[:recommendations]

    render :results, formats: [:html], layout: true
  rescue AnthropicService::RecommendationError => e
    flash[:alert] = "Erro ao gerar recomendações: #{e.message}"
    redirect_to root_path
  end
end
