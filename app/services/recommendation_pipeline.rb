class RecommendationPipeline
  MAX_RETRIES = 5

  def initialize(movies, user = nil)
    @movies = movies
    @user = user
  end

  def call
    candidates = TmdbService.find_candidates(@movies, top_n: 30)
    available = []
    already_recommended = []
    retries = 0

    while available.size < 3 && retries <= MAX_RETRIES
      current_candidates = remaining_candidates(candidates, already_recommended)
      break if current_candidates.empty?

      ai_result = AnthropicService.new(@movies, current_candidates, user_platforms).call
      @analysis ||= ai_result["analysis"]

      new_recs = TmdbService.enrich_recommendations(ai_result["recommendations"])
      already_recommended.concat(new_recs.map { |r| r["title"] })

      new_recs.each do |r|
        next unless r.dig("tmdb", :streaming)&.any?
        if user_has_platforms?
          next unless matches_user_platforms?(r)
        end
        available << r unless available.any? { |a| a["title"] == r["title"] }
      end

      retries += 1
    end

    if available.size < 3 && user_has_platforms?
      genre_ids = candidates.flat_map { |c| c[:genre_ids] || [] }.tally.sort_by { |_, v| -v }.first(3).map(&:first)
      already_titles = already_recommended + available.map { |a| a["title"] }
      platform_candidates = TmdbService.discover_by_platform(user_platforms, genre_ids, already_titles, limit: 15)
      fallback_retries = 0
      while available.size < 3 && fallback_retries < 3 && platform_candidates.any?
        current_candidates = remaining_candidates(platform_candidates, already_recommended)
        break if current_candidates.empty?
        ai_result = AnthropicService.new(@movies, current_candidates, user_platforms).call
        @analysis ||= ai_result["analysis"]
        new_recs = TmdbService.enrich_recommendations(ai_result["recommendations"])
        already_recommended.concat(new_recs.map { |r| r["title"] })
        new_recs.each do |r|
          next unless r.dig("tmdb", :streaming)&.any?
          next unless matches_user_platforms?(r)
          available << r unless available.any? { |a| a["title"] == r["title"] }
        end
        fallback_retries += 1
      end
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
      analysis: @analysis,
      recommendations: final_recs
    }
  end

  private

  def remaining_candidates(candidates, already_recommended)
    candidates.reject { |c| already_recommended.include?(c[:title]) }
  end

  def user_has_platforms?
    @user&.streaming_platforms&.any?
  end

  def user_platforms
    @user&.streaming_platforms || []
  end

  def matches_user_platforms?(rec)
    streaming = rec.dig("tmdb", :streaming) || []
    streaming.any? { |s| @user.streaming_platforms.include?(s[:name]) }
  end
end
