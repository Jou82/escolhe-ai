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

    if @user&.streaming_platforms&.any?
      recommendations = ensure_three_available(recommendations, candidates)
    end

    {
      analysis: ai_result["analysis"],
      recommendations: recommendations
    }
  end

  private

  def ensure_three_available(recommendations, candidates)
    available = filter_by_streaming(recommendations)
    already_recommended = recommendations.map { |r| r["title"] }
    retries = 0

    while available.size < 3 && retries < MAX_RETRIES
      retries += 1

      remaining_candidates = candidates.reject { |c| already_recommended.include?(c[:title]) }
      break if remaining_candidates.empty?

      new_result = AnthropicService.new(@movies, remaining_candidates).call
      new_recs = TmdbService.enrich_recommendations(new_result["recommendations"])

      already_recommended.concat(new_recs.map { |r| r["title"] })
      available.concat(filter_by_streaming(new_recs))
    end

    available.first(3)
  end

  def filter_by_streaming(recommendations)
    user_platforms = @user.streaming_platforms

    recommendations.select do |rec|
      streaming = rec.dig("tmdb", :streaming) || []
      streaming.any? { |s| user_platforms.include?(s[:name]) }
    end
  end
end
