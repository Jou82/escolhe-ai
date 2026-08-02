# Ranks TMDB movie search results for the existing autocomplete UI.
# Title relevance first — not blockbuster popularity.
# JSON shape stays: [{ id, title, year }, ...]
class MovieSearchService
  RESULT_LIMIT = 8
  MIN_VOTES_FOR_RATING = 80
  SPAM_VOTE_FLOOR = 15
  BLOCKBUSTER_POPULARITY = 120.0

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

    exact = title == normalized_query || original == normalized_query
    prefix = title.start_with?(normalized_query) || original.start_with?(normalized_query)
    contains = title.include?(normalized_query) || original.include?(normalized_query)

    score = 0.0

    # 1) Title match dominates ranking.
    if exact
      score += 200
    elsif prefix
      score += 110
    elsif contains
      score += 55
    end

    query_tokens = normalized_query.split.reject { |t| t.length < 2 }
    title_tokens = "#{title} #{original}".split
    if query_tokens.any?
      overlap = query_tokens.count { |token| title_tokens.any? { |t| t.include?(token) } }
      score += (overlap.to_f / query_tokens.size) * 40
    end

    # Prefer shorter titles when match quality is similar
    # ("Matrix" over "The Matrix Reloaded: ...").
    if exact || prefix
      score += [0, 18 - title.split.size].max * 2
    end

    # 2) Quality signal (rating), only when enough votes exist.
    #    No boost for raw popularity / vote volume.
    if votes >= MIN_VOTES_FOR_RATING
      score += (rating - 5.0) * 6
    elsif votes >= SPAM_VOTE_FLOOR
      score += (rating - 5.0) * 2
    end

    # 3) Soft-dampen mega-blockbusters when the title isn't an exact match,
    #    so franchise hits don't bury better-fitting titles.
    if !exact && popularity >= BLOCKBUSTER_POPULARITY
      score -= Math.log10(popularity) * 6
    end

    # 4) Filter noise, not chase hits.
    score -= 50 if movie["poster_path"].blank?
    score -= 40 if votes < SPAM_VOTE_FLOOR && !exact
    score -= 15 if year.blank?

    score += 50 if @year.present? && year == @year

    score
  end

  def normalize(text)
    I18n.transliterate(text.to_s).downcase.gsub(/[^a-z0-9\s]/, " ").squeeze(" ").strip
  end

  def present(movie)
    {
      id: movie["id"],
      title: movie["title"],
      year: movie["release_date"]&.slice(0, 4)
    }
  end
end
