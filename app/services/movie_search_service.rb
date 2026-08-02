# Frozen string support keeps search ranking deterministic and easy to test.
class MovieSearchService
  POSTER_BASE = "https://image.tmdb.org/t/p/w92"
  RESULT_LIMIT = 8
  MIN_VOTES_SOFT = 40

  def self.call(query)
    new(query).call
  end

  def initialize(query)
    @raw_query = query.to_s.strip
    @query, @year = extract_year(@raw_query)
  end

  def call
    return [] if @query.blank? || api_key.blank?

    results = fetch_results
    return [] if results.empty?

    rank(results).first(RESULT_LIMIT).map { |movie| present(movie) }
  end

  private

  def api_key
    ENV.fetch("TMDB_API_KEY", nil)
  end

  def extract_year(text)
    if text =~ /\A(.+?)\s+((?:19|20)\d{2})\z/
      [$1.strip, $2]
    else
      [text, nil]
    end
  end

  def fetch_results
    params = {
      api_key: api_key,
      query: @query,
      language: "pt-BR",
      region: "BR",
      include_adult: false,
      page: 1
    }
    params[:primary_release_year] = @year if @year

    response = Faraday.get("https://api.themoviedb.org/3/search/movie", params)
    return [] unless response.status == 200

    body = response.body
    return [] if body.blank? || body.start_with?("<")

    Array(JSON.parse(body)["results"])
  rescue StandardError => e
    Rails.logger.error "MovieSearchService fetch error: #{e.message}"
    []
  end

  def rank(results)
    normalized = normalize(@query)

    results
      .uniq { |movie| movie["id"] }
      .sort_by { |movie| -relevance_score(movie, normalized) }
  end

  def relevance_score(movie, normalized_query)
    title = normalize(movie["title"])
    original = normalize(movie["original_title"])
    popularity = movie["popularity"].to_f
    votes = movie["vote_count"].to_i
    rating = movie["vote_average"].to_f
    year = movie["release_date"].to_s.slice(0, 4)

    score = 0.0

    # Exact / prefix / contains matches beat raw TMDB order.
    if title == normalized_query || original == normalized_query
      score += 120
    elsif title.start_with?(normalized_query) || original.start_with?(normalized_query)
      score += 70
    elsif title.include?(normalized_query) || original.include?(normalized_query)
      score += 35
    end

    # Token overlap helps multi-word titles ("o poderoso chefao").
    query_tokens = normalized_query.split
    title_tokens = "#{title} #{original}".split
    overlap = query_tokens.count { |token| title_tokens.any? { |t| t.include?(token) } }
    score += overlap * 12

    # Prefer known movies over obscure near-matches.
    score += Math.log10([popularity, 1].max) * 14
    score += Math.log10([votes, 1].max) * 8
    score += rating * 1.5

    # Soft-penalize thin / hard-to-identify results.
    score -= 55 if movie["poster_path"].blank?
    score -= 35 if votes < MIN_VOTES_SOFT && title != normalized_query && original != normalized_query
    score -= 20 if year.blank?

    # If user typed a year, boost that year strongly.
    score += 40 if @year.present? && year == @year

    score
  end

  def normalize(text)
    I18n.transliterate(text.to_s).downcase.gsub(/[^a-z0-9\s]/, " ").squeeze(" ").strip
  end

  def present(movie)
    poster_path = movie["poster_path"]
    {
      id: movie["id"],
      title: movie["title"],
      original_title: movie["original_title"],
      year: movie["release_date"]&.slice(0, 4),
      poster_url: poster_path.present? ? "#{POSTER_BASE}#{poster_path}" : nil,
      rating: movie["vote_average"].to_f.round(1),
      vote_count: movie["vote_count"].to_i,
      overview: movie["overview"].to_s.truncate(110)
    }
  end
end
