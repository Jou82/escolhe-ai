# app/services/tmdb_service.rb
class TmdbService
  BASE_URL    = "https://api.themoviedb.org/3"
  TIMEOUT     = 4
  MAX_RETRIES = 1

  WEIGHTS = {
    frequency: 0.35,
    rating:    0.25,
    popularity: 0.25,
    votes:     0.15
  }.freeze

  PROVIDER_IDS = {
    "Netflix"             => 8,
    "Amazon Prime Video"  => 119,
    "Disney Plus"         => 337,
    "HBO Max"             => 384,
    "Globoplay"           => 307,
    "Apple TV+"           => 350,
    "Paramount+"          => 531,
    "MUBI"                => 11,
    "Telecine"            => 227,
    "Crunchyroll"         => 283,
    "Claro tv+"           => 1968,
    "Star+"               => 619,
    "Looke"               => 47
  }.freeze

  def initialize(title, year = nil)
    @title = title
    @year  = year
  end

  # ─────────────────────────────────────────
  # INSTANCE — chamado por enrich_recommendations
  # ─────────────────────────────────────────

  def call
    movie = search_movie
    return nil unless movie

    movie_id = movie["id"]

    # Dispara providers, cast e trailer em paralelo
    t_providers = Thread.new { fetch_providers(movie_id) }
    t_cast      = Thread.new { fetch_cast(movie_id) }
    t_trailer   = Thread.new { fetch_trailer(movie_id) }

    providers = t_providers.value
    cast      = t_cast.value
    trailer   = t_trailer.value

    {
      tmdb_id:        movie_id,
      title:          movie["title"],
      original_title: movie["original_title"],
      overview:       movie["overview"],
      poster_url:     poster_url(movie["poster_path"]),
      vote_average:   movie["vote_average"],
      release_date:   movie["release_date"],
      streaming:      extract_br_providers(providers, "flatrate"),
      rent:           extract_br_providers(providers, "rent"),
      buy:            extract_br_providers(providers, "buy"),
      cast:           cast,
      trailer_url:    trailer
    }
  end

  # ─────────────────────────────────────────
  # CLASS METHODS — candidatos e enriquecimento
  # ─────────────────────────────────────────

  def self.test_connection
    response = Faraday.get("#{BASE_URL}/movie/550", { api_key: ENV.fetch("TMDB_API_KEY", nil) })
    response.status == 200
  rescue StandardError
    false
  end

  def self.find_candidates(movies, top_n: 15)
    user_movies = movies
      .map { |title| Thread.new { new(title).send(:search_movie) } }
      .filter_map do |t|
        movie = t.value
        next unless movie
        { tmdb_id: movie["id"], title: movie["title"] }
      end

    return [] if user_movies.empty?

    threads = user_movies.flat_map do |um|
      [
        Thread.new { [:related,   um[:tmdb_id], fetch_related(um[:tmdb_id])] },
        Thread.new { [:director,  um[:tmdb_id], fetch_director_filmography(um[:tmdb_id])] }
      ]
    end

    user_director_ids = Set.new
    director_film_ids = Set.new
    similar_by_source = user_movies.each_with_object({}) { |um, h| h[um[:tmdb_id]] = [] }

    threads.each do |t|
      type, tmdb_id, data = t.value
      case type
      when :related
        similar_by_source[tmdb_id].concat(data)
      when :director
        dir_ids, dir_films = data
        user_director_ids.merge(dir_ids)
        director_film_ids.merge(dir_films.map { |f| f["id"] })
        similar_by_source[tmdb_id].concat(dir_films)
      end
    end

    similar_by_source.transform_values! { |v| v.uniq { |m| m["id"] } }
    scored = score_candidates(similar_by_source, user_movies)

    scored.reject { |c| director_film_ids.include?(c[:tmdb_id]) }.first(top_n)
  end

  # Enriquece os 3 filmes recomendados em paralelo
  def self.enrich_recommendations(recommendations)
    threads = recommendations.map do |rec|
      Thread.new do
        tmdb_data = nil
        retries   = 0

        begin
          Timeout.timeout(TIMEOUT) do
            tmdb_data = new(rec["title"], rec["year"]).call
            tmdb_data ||= new(rec["original_title"], rec["year"]).call if rec["original_title"]
          end
        rescue Timeout::Error, Faraday::ConnectionFailed, Faraday::TimeoutError => e
          retries += 1
          if retries <= MAX_RETRIES
            Rails.logger.warn "TMDB enrich timeout (tentativa #{retries}) para '#{rec["title"]}', retrying..."
            sleep(0.5)
            retry
          else
            Rails.logger.warn "TMDB timeout enriching '#{rec["title"]}': #{e.message}"
          end
        end

        rec.merge("tmdb" => tmdb_data)
      end
    end

    threads.map(&:value)
  end

  def self.fetch_related(movie_id)
    with_retry("fetch_related") do
      Timeout.timeout(TIMEOUT) do
        threads = [1, 2].flat_map do |page|
          [
            Thread.new do
              r = Faraday.get("#{BASE_URL}/movie/#{movie_id}/recommendations",
                              { api_key: ENV.fetch("TMDB_API_KEY", nil), language: "pt-BR", page: page })
              JSON.parse(r.body)["results"] || []
            end,
            Thread.new do
              r = Faraday.get("#{BASE_URL}/movie/#{movie_id}/similar",
                              { api_key: ENV.fetch("TMDB_API_KEY", nil), language: "pt-BR", page: page })
              JSON.parse(r.body)["results"] || []
            end
          ]
        end

        threads.flat_map(&:value).uniq { |m| m["id"] }
      end
    end || []
  end

  def self.fetch_director_filmography(movie_id)
    with_retry("fetch_director_filmography") do
      Timeout.timeout(TIMEOUT) do
        credits_response = Faraday.get("#{BASE_URL}/movie/#{movie_id}/credits",
                                       { api_key: ENV.fetch("TMDB_API_KEY", nil) })
        credits   = JSON.parse(credits_response.body)
        directors = credits["crew"]&.select { |c| c["job"] == "Director" } || []
        return [[], []] if directors.empty?

        director_ids = directors.map { |d| d["id"] }
        all_films    = []

        directors.each do |director|
          begin
            Timeout.timeout(TIMEOUT) do
              r = Faraday.get("#{BASE_URL}/person/#{director['id']}/movie_credits",
                              { api_key: ENV.fetch("TMDB_API_KEY", nil), language: "pt-BR" })
              films = JSON.parse(r.body)["crew"]
                        &.select { |c| c["job"] == "Director" }
                        &.reject { |c| c["id"] == movie_id } || []
              all_films.concat(films)
            end
          rescue Timeout::Error, Faraday::ConnectionFailed, Faraday::TimeoutError => e
            Rails.logger.warn "TMDB timeout for director #{director['id']}: #{e.message}"
          end
        end

        [director_ids, all_films]
      end
    end || [[], []]
  end

  def self.discover_by_platform(platform_names, genre_ids, exclude_titles = [], limit: 10)
    provider_ids = platform_names.filter_map { |name| PROVIDER_IDS[name] }
    return [] if provider_ids.empty? || genre_ids.empty?

    results = with_retry("discover_by_platform") do
      Timeout.timeout(TIMEOUT) do
        provider_ids.flat_map do |provider_id|
          r = Faraday.get(
            "#{BASE_URL}/discover/movie",
            {
              api_key:            ENV.fetch("TMDB_API_KEY", nil),
              language:           "pt-BR",
              watch_region:       "BR",
              with_watch_providers: provider_id,
              with_genres:        genre_ids.first(3).join(","),
              sort_by:            "vote_average.desc",
              "vote_count.gte" => 50,
              page:               1
            }
          )
          JSON.parse(r.body)["results"] || []
        end
      end
    end || []

    results.uniq { |m| m["id"] }
           .reject { |m| exclude_titles.include?(m["title"]) }
           .first(limit)
           .map { |movie| normalize_candidate(movie, score: 50) }
  end

  def self.discover_by_single_platform(platform_name, exclude_titles = [], limit: 20)
    provider_id = PROVIDER_IDS[platform_name]
    return [] unless provider_id

    r = Faraday.get(
      "#{BASE_URL}/discover/movie",
      {
        api_key:              ENV.fetch("TMDB_API_KEY", nil),
        language:             "pt-BR",
        watch_region:         "BR",
        with_watch_providers: provider_id,
        sort_by:              "popularity.desc",
        page:                 1,
        "vote_count.gte"   => 50
      }
    )

    (JSON.parse(r.body)["results"] || [])
      .reject { |m| exclude_titles.include?(m["title"]) }
      .first(limit)
      .map { |movie| normalize_candidate(movie, score: 50) }
  end

  # ─────────────────────────────────────────
  # SCORING
  # ─────────────────────────────────────────

  def self.score_candidates(similar_by_source, user_movies)
    user_ids      = user_movies.map { |m| m[:tmdb_id] }
    total_sources = similar_by_source.keys.size
    candidate_map = {}

    similar_by_source.each_value do |similar_movies|
      similar_movies.each do |movie|
        tmdb_id = movie["id"]
        next if user_ids.include?(tmdb_id)

        if candidate_map[tmdb_id]
          candidate_map[tmdb_id][:frequency] += 1
        else
          candidate_map[tmdb_id] = normalize_candidate(movie)
        end
      end
    end

    candidate_map.values
                 .each { |c| c[:score] = calculate_score(c, total_sources) }
                 .sort_by { |c| -c[:score] }
  end

  def self.calculate_score(candidate, total_sources)
    (
      frequency_score(candidate[:frequency], total_sources) * WEIGHTS[:frequency] +
      rating_score(candidate[:vote_average])                * WEIGHTS[:rating]    +
      popularity_score(candidate[:popularity])              * WEIGHTS[:popularity] +
      votes_score(candidate[:vote_count])                   * WEIGHTS[:votes]
    ).round(1)
  end

  def self.frequency_score(frequency, total_sources)
    return 0 if total_sources.zero?
    (frequency.to_f / total_sources * 100).clamp(0, 100)
  end

  def self.rating_score(vote_average)
    (vote_average.to_f * 10).clamp(0, 100)
  end

  def self.popularity_score(popularity)
    case popularity.to_f
    when 10_000.. then 20
    when 1_000..  then 30
    when 100..    then 40
    when 10..     then 10
    else               5
    end
  end

  def self.votes_score(vote_count)
    case vote_count.to_i
    when 10_000.. then 100
    when 5_000..  then 80
    when 1_000..  then 60
    when 500..    then 40
    when 100..    then 20
    else               0
    end
  end

  # ─────────────────────────────────────────
  # PRIVATE
  # ─────────────────────────────────────────

  private

  def search_movie
    params = {
      api_key:  ENV.fetch("TMDB_API_KEY", nil),
      query:    @title,
      language: "pt-BR",
      region:   "BR"
    }
    params[:year] = @year if @year

    response = Faraday.get("#{BASE_URL}/search/movie", params)
    return nil unless response.status == 200

    body = response.body
    return nil if body.nil? || body.start_with?("<")

    JSON.parse(body)["results"]&.first
  rescue JSON::ParserError, Faraday::Error => e
    Rails.logger.warn "TMDB error searching '#{@title}': #{e.message}"
    nil
  end

  def fetch_trailer(movie_id)
    # Dispara PT-BR e EN em paralelo — usa o melhor disponível
    t_ptbr = Thread.new do
      r = Faraday.get("#{BASE_URL}/movie/#{movie_id}/videos",
                      { api_key: ENV.fetch("TMDB_API_KEY", nil), language: "pt-BR" })
      JSON.parse(r.body)["results"] || []
    end

    t_en = Thread.new do
      r = Faraday.get("#{BASE_URL}/movie/#{movie_id}/videos",
                      { api_key: ENV.fetch("TMDB_API_KEY", nil), language: "en-US" })
      JSON.parse(r.body)["results"] || []
    end

    trailer = t_ptbr.value.find { |v| v["type"] == "Trailer" && v["site"] == "YouTube" }
    trailer ||= t_en.value.find { |v| v["type"] == "Trailer" && v["site"] == "YouTube" }
    trailer ? "https://www.youtube.com/watch?v=#{trailer["key"]}" : nil
  rescue StandardError => e
    Rails.logger.warn "TMDB error fetching trailer for #{movie_id}: #{e.message}"
    nil
  end

  def fetch_providers(movie_id)
    response = Faraday.get(
      "#{BASE_URL}/movie/#{movie_id}/watch/providers",
      { api_key: ENV.fetch("TMDB_API_KEY", nil) }
    )
    JSON.parse(response.body)["results"]
  end

  def fetch_cast(movie_id)
    response = Faraday.get(
      "#{BASE_URL}/movie/#{movie_id}/credits",
      { api_key: ENV.fetch("TMDB_API_KEY", nil), language: "pt-BR" }
    )
    credits = JSON.parse(response.body)
    (credits["cast"] || []).first(6).map do |member|
      {
        name:      member["name"],
        character: member["character"],
        photo_url: member["profile_path"] ? poster_url(member["profile_path"], "w185") : nil
      }
    end
  rescue StandardError => e
    Rails.logger.warn "TMDB error fetching cast for #{movie_id}: #{e.message}"
    []
  end

  def extract_br_providers(providers, type)
    br_data = providers&.dig("BR") || {}
    link    = br_data["link"]
    items   = br_data[type] || []

    items
      .reject { |p| p["provider_name"].to_s.downcase.match?(/with ads|ads$/) }
      .map do |p|
        {
          name:     p["provider_name"],
          logo_url: poster_url(p["logo_path"], "w92"),
          link:     link
        }
      end
  end

  def poster_url(path, size = "w500")
    return nil unless path
    "https://image.tmdb.org/t/p/#{size}#{path}"
  end

  # Helper partilhado de retry para class methods
  def self.with_retry(method_name, &block)
    retries = 0
    begin
      block.call
    rescue Timeout::Error, Faraday::ConnectionFailed, Faraday::TimeoutError => e
      retries += 1
      if retries <= MAX_RETRIES
        Rails.logger.warn "TMDB #{method_name} timeout (tentativa #{retries}), retrying..."
        sleep(0.5)
        retry
      else
        Rails.logger.error "TMDB #{method_name} falhou: #{e.message}"
        nil
      end
    end
  end
  private_class_method :with_retry

  # Normaliza um hash de filme da API para o formato interno
  def self.normalize_candidate(movie, score: nil)
    candidate = {
      tmdb_id:        movie["id"],
      title:          movie["title"],
      original_title: movie["original_title"],
      overview:       movie["overview"],
      poster_path:    movie["poster_path"],
      vote_average:   movie["vote_average"] || 0,
      vote_count:     movie["vote_count"]   || 0,
      popularity:     movie["popularity"]   || 0,
      release_date:   movie["release_date"],
      genre_ids:      movie["genre_ids"]    || [],
      frequency:      1
    }
    candidate[:score] = score if score
    candidate
  end
  private_class_method :normalize_candidate
end
