class RecommendationPipeline
  MAX_RETRIES = 2

  def initialize(movies, user = nil)
    @movies = movies
    @user = user
  end

  def call
    candidates = TmdbService.find_candidates(@movies, top_n: 15)
    ai_result = AnthropicService.new(@movies, candidates).call
    recommendations = TmdbService.enrich_recommendations(ai_result["recommendations"])

    # Filtrar por streaming disponível
    available = recommendations.select { |r| r.dig("tmdb", :streaming)&.any? }

    # Se user tem plataformas salvas, filtra só por elas
    if @user&.streaming_platforms&.any?
      available = filter_by_user_platforms(available)
    end

    retries = 0
    already_recommended = recommendations.map { |r| r["title"] }

    while available.size < 3 && retries < MAX_RETRIES
      retries += 1
      remaining_candidates = candidates.reject { |c| already_recommended.include?(c[:title]) }
      break if remaining_candidates.empty?

      new_result = AnthropicService.new(@movies, remaining_candidates).call
      new_recs = TmdbService.enrich_recommendations(new_result["recommendations"])
      already_recommended.concat(new_recs.map { |r| r["title"] })

      new_available = new_recs.select { |r| r.dig("tmdb", :streaming)&.any? }
      if @user&.streaming_platforms&.any?
        new_available = filter_by_user_platforms(new_available)
      end
      available.concat(new_available)
    end

    final_recs = available.first(3).map do |rec|
      if rec["tmdb"].is_a?(Hash)
        rec["tmdb"] = rec["tmdb"].transform_keys(&:to_s)
        rec["tmdb"]["streaming"] = rec["tmdb"]["streaming"]&.map { |s| s.transform_keys(&:to_s) }
        rec["tmdb"]["rent"] = rec["tmdb"]["rent"]&.map { |r| r.transform_keys(&:to_s) }
        rec["tmdb"]["buy"] = rec["tmdb"]["buy"]&.map { |b| b.transform_keys(&:to_s) }
      end
      rec
    end

    {
      analysis: ai_result["analysis"],
      recommendations: final_recs
    }
  end

  private

  def filter_by_user_platforms(recommendations)
    user_platforms = @user.streaming_platforms

    recommendations.select do |rec|
      streaming = rec.dig("tmdb", :streaming) || []
      streaming.any? { |s| user_platforms.include?(s[:name]) }
    end
  end
end
