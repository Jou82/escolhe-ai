# app/services/tmdb_service.rb
class TmdbService
  BASE_URL = "https://api.themoviedb.org/3"

  # 🔥 NOVAS CONSTANTES (já estão no seu código)
  TIMEOUT = 8
  MAX_RETRIES = 2

  def initialize(title, year = nil)
    @title = title
    @year = year
  end

  WEIGHTS = {
    frequency: 0.35,
    rating: 0.25,
    popularity: 0.25,
    votes: 0.15
  }.freeze

  PROVIDER_IDS = {
    "Netflix" => 8,
    "Amazon Prime Video" => 119,
    "Disney Plus" => 337,
    "HBO Max" => 384,
    "Globoplay" => 307,
    "Apple TV+" => 350,
    "Paramount+" => 531,
    "MUBI" => 11,
    "Telecine" => 227,
    "Crunchyroll" => 283,
    "Claro tv+" => 1968,
    "Star+" => 619,
    "Looke" => 47
  }.freeze

  # 🔥 NOVO: Método para testar conexão (usado na detecção de rede)
  def self.test_connection
    response = Faraday.get(
      "#{BASE_URL}/movie/550",
      { api_key: ENV.fetch("TMDB_API_KEY", nil) }
    )
    response.status == 200
  rescue
    false
  end

  def self.find_candidates(movies, top_n: 15)
    # 1. Buscar os 3 filmes em paralelo
    user_movies = movies.map { |title| Thread.new { new(title).send(:search_movie) } }
                        .filter_map do |t|
                          movie = t.value
                          next unless movie

                          { tmdb_id: movie["id"], title: movie["title"] }
                        end

    return [] if user_movies.empty?

    # 2. Buscar relacionados + filmografia do diretor em paralelo (2 threads por filme)
    threads = user_movies.flat_map do |um|
      [
        Thread.new { [:related, um[:tmdb_id], fetch_related(um[:tmdb_id])] },
        Thread.new { [:director, um[:tmdb_id], fetch_director_filmography(um[:tmdb_id])] }
      ]
    end

    # 3. Coletar resultados
    user_director_ids = Set.new
    similar_by_source = {}
    director_film_ids = Set.new

    # Inicializar
    user_movies.each { |um| similar_by_source[um[:tmdb_id]] = [] }

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

    # Deduplicar por fonte
    similar_by_source.transform_values! { |v| v.uniq { |m| m["id"] } }

    scored = score_candidates(similar_by_source, user_movies)

    # Remover filmes dos mesmos diretores APÓS o scoring (sem chamadas extras!)
    scored.reject { |c| director_film_ids.include?(c[:tmdb_id]) }
          .first(top_n)
  end

  # 🔥 MÉTODO COM TIMEOUT E RETRY (já está no seu código)
  def self.fetch_related(movie_id)
    retries = 0

    begin
      Timeout.timeout(TIMEOUT) do
        threads = [1, 2].flat_map do |page|
          [
            Thread.new do
              response = Faraday.get(
                "#{BASE_URL}/movie/#{movie_id}/recommendations",
                { api_key: ENV.fetch("TMDB_API_KEY", nil), language: "pt-BR", page: page }
              )
              JSON.parse(response.body)["results"] || []
            end,
            Thread.new do
              response = Faraday.get(
                "#{BASE_URL}/movie/#{movie_id}/similar",
                { api_key: ENV.fetch("TMDB_API_KEY", nil), language: "pt-BR", page: page }
              )
              JSON.parse(response.body)["results"] || []
            end
          ]
        end

        all = threads.flat_map(&:value)
        all.uniq { |m| m["id"] }
      end
    rescue Timeout::Error, Faraday::ConnectionFailed, Faraday::TimeoutError => e
      retries += 1
      if retries <= MAX_RETRIES
        Rails.logger.warn "TMDB fetch_related timeout (tentativa #{retries}), tentando novamente..."
        sleep(2)
        retry
      else
        Rails.logger.error "TMDB fetch_related falhou: #{e.message}"
        []
      end
    end
  end

  # 🔥 MÉTODO COM TIMEOUT E RETRY (já está no seu código)
  def self.fetch_director_filmography(movie_id)
    retries = 0

    begin
      Timeout.timeout(TIMEOUT) do
        credits_response = Faraday.get(
          "#{BASE_URL}/movie/#{movie_id}/credits",
          { api_key: ENV.fetch("TMDB_API_KEY", nil) }
        )
        credits = JSON.parse(credits_response.body)
        directors = credits["crew"]&.select { |c| c["job"] == "Director" } || []
        return [[], []] if directors.empty?

        director_ids = directors.map { |d| d["id"] }
        all_films = []

        directors.each do |director|
          begin
            Timeout.timeout(TIMEOUT) do
              person_response = Faraday.get(
                "#{BASE_URL}/person/#{director['id']}/movie_credits",
                { api_key: ENV.fetch("TMDB_API_KEY", nil), language: "pt-BR" }
              )
              person_credits = JSON.parse(person_response.body)
              films = person_credits["crew"]
                      &.select { |c| c["job"] == "Director" }
                      &.reject { |c| c["id"] == movie_id } || []
              all_films.concat(films)
            end
          rescue Timeout::Error, Faraday::ConnectionFailed, Faraday::TimeoutError => e
            Rails.logger.warn "TMDB timeout for director #{director['id']}: #{e.message}"
            next
          end
        end

        [director_ids, all_films]
      end
    rescue Timeout::Error, Faraday::ConnectionFailed, Faraday::TimeoutError => e
      retries += 1
      if retries <= MAX_RETRIES
        Rails.logger.warn "TMDB fetch_director_filmography timeout (tentativa #{retries}), tentando novamente..."
        sleep(2)
        retry
      else
        Rails.logger.error "TMDB fetch_director_filmography falhou: #{e.message}"
        [[], []]
      end
    end
  end

  def self.score_candidates(similar_by_source, user_movies)
    user_ids = user_movies.map { |m| m[:tmdb_id] }
    total_sources = similar_by_source.keys.size
    candidate_map = {}

    similar_by_source.each_value do |similar_movies|
      similar_movies.each do |movie|
        tmdb_id = movie["id"]
        next if user_ids.include?(tmdb_id)

        if candidate_map[tmdb_id]
          candidate_map[tmdb_id][:frequency] += 1
        else
          candidate_map[tmdb_id] = {
            tmdb_id: tmdb_id,
            title: movie["title"],
            original_title: movie["original_title"],
            overview: movie["overview"],
            poster_path: movie["poster_path"],
            vote_average: movie["vote_average"] || 0,
            vote_count: movie["vote_count"] || 0,
            popularity: movie["popularity"] || 0,
            release_date: movie["release_date"],
            genre_ids: movie["genre_ids"] || [],
            frequency: 1
          }
        end
      end
    end

    candidate_map.values.each { |c| c[:score] = calculate_score(c, total_sources) }
                 .sort_by { |c| -c[:score] }
  end

  def self.calculate_score(candidate, total_sources)
    freq = frequency_score(candidate[:frequency], total_sources)
    rating = rating_score(candidate[:vote_average])
    pop = popularity_score(candidate[:popularity])
    votes = votes_score(candidate[:vote_count])

    ((freq * WEIGHTS[:frequency]) +
     (rating * WEIGHTS[:rating]) +
     (pop * WEIGHTS[:popularity]) +
     (votes * WEIGHTS[:votes])).round(1)
  end

  def self.frequency_score(frequency, total_sources)
    return 0 if total_sources.zero?

    (frequency.to_f / total_sources * 100).clamp(0, 100)
  end

  def self.rating_score(vote_average)
    (vote_average.to_f * 10).clamp(0, 100)
  end

  def self.popularity_score(popularity)
    pop = popularity.to_f
    if pop >= 10_000
      20
    elsif pop >= 1_000
      30
    elsif pop >= 100
      40
    elsif pop >= 10
      10
    else
      5
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

  # 🔥 MÉTODO COM TIMEOUT E RETRY (já está no seu código)
  def self.discover_by_platform(platform_names, genre_ids, exclude_titles = [], limit: 10)
    provider_ids = platform_names.filter_map { |name| PROVIDER_IDS[name] }
    return [] if provider_ids.empty? || genre_ids.empty?

    results = []
    retries = 0

    begin
      Timeout.timeout(TIMEOUT) do
        provider_ids.each do |provider_id|
          response = Faraday.get(
            "#{BASE_URL}/discover/movie",
            {
              api_key: ENV.fetch("TMDB_API_KEY", nil),
              language: "pt-BR",
              watch_region: "BR",
              with_watch_providers: provider_id,
              with_genres: genre_ids.first(3).join(","),
              sort_by: "vote_average.desc",
              "vote_count.gte" => 50,
              page: 1
            }
          )
          movies = JSON.parse(response.body)["results"] || []
          results.concat(movies)
        end
      end
    rescue Timeout::Error, Faraday::ConnectionFailed, Faraday::TimeoutError => e
      retries += 1
      if retries <= MAX_RETRIES
        Rails.logger.warn "TMDB discover_by_platform timeout (tentativa #{retries}), tentando novamente..."
        sleep(2)
        retry
      else
        Rails.logger.error "TMDB discover_by_platform falhou: #{e.message}"
        return []
      end
    end

    results.uniq { |m| m["id"] }
           .reject { |m| exclude_titles.include?(m["title"]) }
           .first(limit)
           .map do |movie|
      {
        tmdb_id: movie["id"],
        title: movie["title"],
        original_title: movie["original_title"],
        overview: movie["overview"],
        poster_path: movie["poster_path"],
        vote_average: movie["vote_average"] || 0,
        vote_count: movie["vote_count"] || 0,
        popularity: movie["popularity"] || 0,
        release_date: movie["release_date"],
        genre_ids: movie["genre_ids"] || [],
        frequency: 1,
        score: 50
      }
    end
  end

  def call
    movie = search_movie
    return nil unless movie

    providers = fetch_providers(movie["id"])

    {
      tmdb_id: movie["id"],
      title: movie["title"],
      original_title: movie["original_title"],
      overview: movie["overview"],
      poster_url: poster_url(movie["poster_path"]),
      vote_average: movie["vote_average"],
      release_date: movie["release_date"],
      streaming: extract_br_providers(providers, "flatrate"),
      rent: extract_br_providers(providers, "rent"),
      buy: extract_br_providers(providers, "buy")
    }
  end

  # 🔥 MÉTODO COM TIMEOUT E RETRY (já está no seu código)
  def self.enrich_recommendations(recommendations)
    recommendations.map do |rec|
      retries = 0
      tmdb_data = nil

      begin
        Timeout.timeout(TIMEOUT) do
          tmdb_data = new(rec["title"], rec["year"]).call

          if tmdb_data.nil? && rec["original_title"]
            tmdb_data = new(rec["original_title"], rec["year"]).call
          end
        end
      rescue Timeout::Error, Faraday::ConnectionFailed, Faraday::TimeoutError => e
        retries += 1
        if retries <= MAX_RETRIES
          Rails.logger.warn "TMDB enrich timeout (tentativa #{retries}) para '#{rec["title"]}', tentando novamente..."
          sleep(2)
          retry
        else
          Rails.logger.warn "TMDB timeout enriching '#{rec["title"]}': #{e.message}"
          tmdb_data = nil
        end
      end

      rec.merge("tmdb" => tmdb_data)
    end
  end

  private

  def search_movie
    params = {
      api_key: ENV.fetch("TMDB_API_KEY", nil),
      query: @title,
      language: "pt-BR",
      region: "BR"
    }
    params[:year] = @year if @year

    response = Faraday.get("#{BASE_URL}/search/movie", params)
    return nil unless response.status == 200

    body = response.body
    return nil if body.nil? || body.start_with?("<")

    results = JSON.parse(body)["results"]
    results&.first
  rescue JSON::ParserError, Faraday::Error => e
    Rails.logger.warn("TMDB error searching '#{@title}': #{e.message}")
    nil
  end

  def fetch_providers(movie_id)
    response = Faraday.get(
      "#{BASE_URL}/movie/#{movie_id}/watch/providers",
      { api_key: ENV.fetch("TMDB_API_KEY", nil) }
    )
    JSON.parse(response.body)["results"]
  end

  def extract_br_providers(providers, type)
    br_data = providers&.dig("BR") || {}
    link = br_data["link"]
    items = br_data[type] || []

    items.reject { |p| p["provider_name"].to_s.downcase.include?("ads") || p["provider_name"].to_s.downcase.include?("with ads") }
         .map do |p|
      {
        name: p["provider_name"],
        logo_url: poster_url(p["logo_path"], "w92"),
        link: link
      }
    end
  end

  def poster_url(path, size = "w500")
    return nil unless path

    "https://image.tmdb.org/t/p/#{size}#{path}"
  end
end
