class RecommendationPipeline
  def initialize(movies)
    @movies = movies
  end

  def call
    candidates = TmdbService.find_candidates(@movies, top_n: 10)

    if candidates.any?
      ai_result = AnthropicService.new(@movies, candidates).call
    else
      Rails.logger.warn("TMDB sem candidatos - fallback IA livre")
      ai_result = AnthropicService.new(@movies).call
    end

    recommendations = TmdbService.enrich_recommendations(ai_result["recommendations"])

    { recommendations: recommendations, analysis: ai_result["analysis"] }
  end
end
