class RecommendationPipeline

  MAX_RETRIES = 2

  def initialize(movies, user= nil)
    @movies = movies
    @user = user
  end

  def call
    candidates = TmdbService.find_candidates(@movies, top_n: 10)
    ai_result = AnthropicService.new(@movies, candidates).call
    recommendations = TmdbService.enrich_recommendations(ai_result["recommendations"])

    if @user&.streaming_platforms.any?
      recommendations = filter_by_streaming(recommendations)
    end

    {
      analysis: ai_result["analysis"],
      recommendations: recommendations
    }
  end

  private

  def 

  def filter_by_streaming(recommendations)
    user_platforms = @user.streaming_platforms

    recommendations.select do |rec|
      streaming = rec.dig("tmdb", :streaming) || []
      streaming.any? { |s| user_platforms.include?(s[:name]) }
    end
  end
end
