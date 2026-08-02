# app/services/recommendation_pipeline.rb
require 'parallel'

class RecommendationPipeline
  MAX_RETRIES = 2
  TMDB_TIMEOUT = 12
  ANTHROPIC_TIMEOUT = 20
  MAX_EXCLUDE_HISTORY = 30 # ← NOVO: Limita histórico de exclusão

  def initialize(movies, user = nil, exclude = [])
    @movie_inputs = Array(movies).map { |entry| TmdbService.normalize_input(entry) }
    @movies = @movie_inputs.map { |entry| entry[:title] }.reject(&:blank?)
    @user = user
    @exclude = exclude
    @candidates = []
  end

  def call
    # NOVO: Limita o histórico de exclusão aos últimos 30 filmes
    limited_exclude = @exclude.last(MAX_EXCLUDE_HISTORY)
    Rails.logger.info "📊 Exclude limitado: #{@exclude.size} → #{limited_exclude.size} filmes"

    @candidates = fetch_candidates_guaranteed
    # Garantir que candidates seja um array
    @candidates ||= []
    if @candidates.empty?
      Rails.logger.error "❌ Nenhum candidato encontrado. Abortando pipeline."
      return { analysis: nil, recommendations: [] }
    end

    platform_movies = []
    rent_buy_movies = []
    already_recommended = limited_exclude.dup # ALTERADO: usa limited_exclude
    retries = 0

    # Prioridade: tentar obter 3 filmes da plataforma
    while platform_movies.size < 3 && retries <= MAX_RETRIES * 2
      current_candidates = remaining_candidates(@candidates, already_recommended)
      break if current_candidates.empty?

      ai_result = fetch_ai_guaranteed(current_candidates, limited_exclude) # ALTERADO: passa limited_exclude
      @analysis ||= ai_result["analysis"] if ai_result

      if ai_result.nil?
        retries += 1
        next
      end

      new_recs = enrich_guaranteed(ai_result["recommendations"])
      already_recommended.concat(new_recs.map { |r| r["title"] })

      new_recs.each do |movie|
        if user_has_platforms?
          streaming_match = movie.dig("tmdb", :streaming)&.any? { |s| user_platforms.include?(s[:name]) }
          rent_match = movie.dig("tmdb", :rent)&.any? { |s| user_platforms.include?(s[:name]) }
          buy_match = movie.dig("tmdb", :buy)&.any? { |s| user_platforms.include?(s[:name]) }

          if streaming_match || rent_match || buy_match
            movie["_type"] = "platform"
            platform_movies << movie unless platform_movies.any? { |m| m["title"] == movie["title"] }
          elsif movie.dig("tmdb", :rent)&.any? || movie.dig("tmdb", :buy)&.any?
            movie["_type"] = "rent_buy"
            rent_buy_movies << movie unless rent_buy_movies.any? { |m| m["title"] == movie["title"] }
          end
        elsif movie.dig("tmdb", :streaming)&.any? ||
              movie.dig("tmdb", :rent)&.any? ||
              movie.dig("tmdb", :buy)&.any?
          rent_buy_movies << movie unless rent_buy_movies.any? { |m| m["title"] == movie["title"] }
        end
      end

      retries += 1
    end

    # ========== FASE 2: PARALELIZADA ==========
    if user_has_platforms? && platform_movies.size < 3
      Rails.logger.info "🎯 Buscando filmes nas plataformas: #{user_platforms.join(', ')} em paralelo..."

      # 🔥 Busca em paralelo em todas as plataformas
      platform_results = Parallel.map(user_platforms, in_threads: user_platforms.size) do |platform|
        results = []
        platform_candidates = TmdbService.discover_by_single_platform(platform, already_recommended, limit: 20)

        platform_candidates.each do |candidate|
          tmdb_data = TmdbService.new(candidate[:title], candidate[:release_date]&.slice(0, 4)).call
          next unless tmdb_data

          streaming_match = tmdb_data[:streaming]&.any? { |s| user_platforms.include?(s[:name]) }
          rent_match = tmdb_data[:rent]&.any? { |s| user_platforms.include?(s[:name]) }
          buy_match = tmdb_data[:buy]&.any? { |s| user_platforms.include?(s[:name]) }

          if streaming_match || rent_match || buy_match
            genres = tmdb_data[:genres] || []
            results << {
              "title" => candidate[:title],
              "original_title" => candidate[:original_title] || candidate[:title],
              "year" => candidate[:release_date]&.slice(0, 4)&.to_i || 2024,
              "reason" => nil,
              "genres" => genres,
              "tmdb" => tmdb_data,
              "_type" => "platform"
            }
          end
          break if results.size >= 3
        end
        results
      end

      # Combina os resultados de todas as plataformas
      platform_movies = platform_results.flatten.uniq { |m| m["title"] }
      platform_movies = platform_movies.first(3)
    end

    # ========== FASE 3: PARALELIZADA ==========
    if user_has_platforms? && rent_buy_movies.empty?
      Rails.logger.info "🎯 Buscando filmes para alugar/comprar em paralelo..."

      rent_buy_candidates = fetch_rent_buy_candidates(already_recommended + platform_movies.map { |m| m["title"] })

      # 🔥 Busca dados de todos os candidatos em paralelo
      rent_buy_results = Parallel.map(rent_buy_candidates, in_threads: 3) do |candidate|
        tmdb_data = TmdbService.new(candidate[:title], candidate[:release_date]&.slice(0, 4)).call
        next unless tmdb_data

        next unless tmdb_data[:rent].any? || tmdb_data[:buy].any?

        genres = tmdb_data[:genres] || []
        {
          "title" => candidate[:title],
          "original_title" => candidate[:original_title] || candidate[:title],
          "year" => candidate[:release_date]&.slice(0, 4)&.to_i || 2024,
          "reason" => nil,
          "genres" => genres,
          "tmdb" => tmdb_data,
          "_type" => "rent_buy"
        }
      end.compact

      rent_buy_movies = rent_buy_results.uniq { |m| m["title"] }
      rent_buy_movies = rent_buy_movies.first(1) if rent_buy_movies.any?
    end

    # ========== COMBINAÇÃO FINAL ==========
    if platform_movies.size >= 3
      available = platform_movies.first(3)
    elsif platform_movies.size >= 2
      available = platform_movies.first(2) + rent_buy_movies.first(1)
    else
      available = rent_buy_movies.first(3)
    end

    available = (platform_movies + rent_buy_movies).first(3) if available.size < 3

    available = fetch_popular_fallback(already_recommended) if available.empty?

    # ========== GARANTIR QUE O CAMPO "reason" SEJA PERSONALIZADO ==========
    final_recs = available.first(3).map do |movie|
      movie.delete("_type")
      movie["reason"] = generate_personalized_reason(movie) if movie["reason"].blank?
      if movie["tmdb"].is_a?(Hash)
        movie["tmdb"] = movie["tmdb"].transform_keys(&:to_s)
        movie["tmdb"]["streaming"] = movie["tmdb"]["streaming"]&.map { |s| s.transform_keys(&:to_s) }
        movie["tmdb"]["rent"] = movie["tmdb"]["rent"]&.map { |r| r.transform_keys(&:to_s) }
        movie["tmdb"]["buy"] = movie["tmdb"]["buy"]&.map { |b| b.transform_keys(&:to_s) }
      end
      movie
    end

    # ========== FILTRO FINAL PARA EVITAR REPETIÇÃO ==========
    # Usa @exclude completo (não limitado) para garantir que nenhum filme já recomendado volte
    final_recs = filter_recommendations(final_recs, @exclude)

    {
      analysis: @analysis,
      recommendations: final_recs
    }
  end

  private

  def generate_personalized_reason(movie)
    title = movie["title"] || movie[:title]
    year  = movie["year"]  || movie[:year] || movie[:release_date]&.slice(0, 4)

    cache_key = "anthropic:reason:#{@movies.sort.join('_')}:#{title}"

    cached = Rails.cache.read(cache_key)
    if cached
      Rails.logger.info "💾 [REASON CACHE] Hit para '#{title}'"
      return cached
    end

    tmdb = movie["tmdb"] || movie[:tmdb] || {}
    overview = tmdb[:overview] || tmdb["overview"]
    genres = (tmdb[:genres] || tmdb["genres"] || movie["genres"] || movie[:genres] || []).first(3).join(", ")
    cast = (tmdb[:cast] || tmdb["cast"] || []).first(3).map { |c| c[:name] || c["name"] }.join(", ")

    movie_context = "Título: #{title} (#{year})"
    movie_context += " | Géneros: #{genres}" if genres.present?
    movie_context += " | Sinopse: #{overview}" if overview.present?
    movie_context += " | Elenco: #{cast}" if cast.present?

    client = Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY", nil))
    Timeout.timeout(10) do
      response = client.messages.create(
        model: "claude-haiku-4-5-20251001",
        max_tokens: 200,
        messages: [
          {
            role: "user",
            content: "Filmes favoritos do usuário: #{@movies.join(', ')}.\n" \
                     "Filme recomendado — #{movie_context}.\n" \
                     "Escreva em 1 frase explicando a ligação DIRETA entre este filme e os filmes favoritos do usuário. " \
                     "Exemplo: 'Se você curtiu [filme favorito] pela [característica], vai amar [filme recomendado] porque [conexão específica].' " \
                     "Tom descontraído, como se fosse um amigo indicando. Responda só o texto, sem aspas."
          }
        ]
      )
      result = response.content.first.text.strip
      Rails.cache.write(cache_key, result, expires_in: 24.hours)
      result
    end
  rescue StandardError => e
    Rails.logger.warn("Erro ao gerar reason: #{e.message}")
    "Recomendado baseado nos seus filmes favoritos: #{@movies.join(', ')}."
  end

  def user_movies_genres_from_tmdb
    @user_movies_genres_from_tmdb ||= begin
      genres = Set.new
      @movie_inputs.each do |input|
        tmdb_data = TmdbService.new(input[:title], input[:year], tmdb_id: input[:tmdb_id]).call
        genres.merge(tmdb_data[:genres]) if tmdb_data && tmdb_data[:genres]
      end
      genres.to_a
    rescue StandardError => e
      Rails.logger.warn "Não foi possível buscar gêneros dos filmes do usuário no TMDB: #{e.message}"
      []
    end
  end

  def fetch_rent_buy_candidates(exclude_titles)
    retries = 0
    loop do
      Timeout.timeout(TMDB_TIMEOUT) do
        response = Faraday.get(
          "#{TmdbService::BASE_URL}/discover/movie",
          {
            api_key: ENV.fetch("TMDB_API_KEY", nil),
            language: "pt-BR",
            watch_region: "BR",
            sort_by: "popularity.desc",
            page: 1,
            "vote_count.gte" => 100
          }
        )
        movies = JSON.parse(response.body)["results"] || []

        return movies.reject { |m| exclude_titles.include?(m["title"]) }
                     .first(20)
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
    rescue Timeout::Error, Errno::ECONNREFUSED, SocketError => e
      retries += 1
      raise e if retries > MAX_RETRIES
      wait_time = [2**retries, 10].min
      Rails.logger.warn "TMDB rent/buy tentativa #{retries} falhou: #{e.message}. Aguardando #{wait_time}s..."
      sleep(wait_time)
    end
  end

  def fetch_popular_fallback(exclude_titles)
    retries = 0
    loop do
      Timeout.timeout(TMDB_TIMEOUT) do
        response = Faraday.get(
          "#{TmdbService::BASE_URL}/movie/popular",
          { api_key: ENV.fetch("TMDB_API_KEY", nil), language: "pt-BR" }
        )
        movies = JSON.parse(response.body)["results"] || []
        movies = movies.reject { |m| exclude_titles.include?(m["title"]) }.first(5)

        return movies.map do |m|
          {
            "title" => m["title"],
            "original_title" => m["original_title"],
            "year" => m["release_date"]&.slice(0, 4)&.to_i || 2024,
            "reason" => nil,
            "genres" => [],
            "tmdb" => {
              "streaming" => [],
              "rent" => [],
              "buy" => [],
              "overview" => m["overview"],
              "release_date" => m["release_date"]
            },
            "_type" => "fallback"
          }
        end
      end
    rescue StandardError => e
      retries += 1
      wait_time = [2**retries, 10].min
      Rails.logger.warn "Fallback popular tentativa #{retries} falhou: #{e.message}. Aguardando #{wait_time}s..."
      sleep(wait_time)
      retry if retries < 3
      return []
    end
  end

  def fetch_candidates_guaranteed
    retries = 0
    loop do
      Timeout.timeout(TMDB_TIMEOUT) do
        tmdb_candidates = TmdbService.find_candidates(@movie_inputs, top_n: 15)
        arthouse_candidates = TmdbService.discover_arthouse_candidates(
          @exclude.last(MAX_EXCLUDE_HISTORY),
          limit: 15
        )

        Rails.logger.info "🎬 TMDB: #{tmdb_candidates.size} | 🎨 Arthouse: #{arthouse_candidates.size}"

        combined = (tmdb_candidates + arthouse_candidates).shuffle
        return combined if combined.present?
      end
    rescue Timeout::Error, Errno::ECONNREFUSED, SocketError => e
      retries += 1
      raise e if retries > MAX_RETRIES
      wait_time = [2**retries, 10].min
      Rails.logger.warn "Candidatos tentativa #{retries} falhou: #{e.message}. Aguardando #{wait_time}s..."
      sleep(wait_time)
    end
  end

  def enrich_guaranteed(recommendations)
    retries = 0
    loop do
      Timeout.timeout(TMDB_TIMEOUT) do
        return TmdbService.enrich_recommendations_with_cache(recommendations)
      end
    rescue Timeout::Error, Errno::ECONNREFUSED, SocketError => e
      retries += 1
      raise e if retries > MAX_RETRIES
      wait_time = [2**retries, 10].min
      Rails.logger.warn "TMDB enrich tentativa #{retries} falhou: #{e.message}. Aguardando #{wait_time}s..."
      sleep(wait_time)
    end
  end

  def fetch_ai_guaranteed(candidates, limited_exclude)
    retries = 0
    loop do
      Timeout.timeout(ANTHROPIC_TIMEOUT) do
        return AnthropicService.new(@movies, candidates, user_platforms, limited_exclude).call
      end
    rescue Timeout::Error => e
      retries += 1
      raise e if retries > MAX_RETRIES
      wait_time = [2**retries, 10].min
      Rails.logger.warn "Anthropic tentativa #{retries} falhou: #{e.message}. Aguardando #{wait_time}s..."
      sleep(wait_time)
    rescue StandardError => e
      retries += 1
      raise e if retries > MAX_RETRIES
      wait_time = [2**retries, 10].min
      Rails.logger.warn "Anthropic erro #{retries}: #{e.message}. Aguardando #{wait_time}s..."
      sleep(wait_time)
    end
  end

  def remaining_candidates(candidates, already_recommended)
    return [] if candidates.blank?

    candidates.reject { |c| already_recommended.include?(c[:title]) }
  end

  def user_has_platforms?
    @user&.streaming_platforms&.any?
  end

  def user_platforms
    @user&.streaming_platforms || []
  end

  # NOVO MÉTODO: Filtra recomendações para evitar repetição
  def filter_recommendations(recommendations, exclude_titles)
    filtered = recommendations.reject do |rec|
      exclude_titles.include?(rec["title"]) ||
        exclude_titles.include?(rec["original_title"])
    end

    Rails.logger.info "🔍 Filtro: #{recommendations.size} → #{filtered.size} recomendações (excluindo: #{exclude_titles.join(', ')})"

    if filtered.size < 3
      needed = 3 - filtered.size
      Rails.logger.warn "⚠️ Faltam #{needed} recomendações. Buscando alternativas..."

      more_candidates = @candidates.reject do |c|
        exclude_titles.include?(c[:title]) ||
          filtered.any? { |r| r["title"] == c[:title] }
      end

      more_candidates.first(needed).each do |candidate|
        filtered << {
          "title" => candidate[:title],
          "original_title" => candidate[:original_title],
          "year" => candidate[:release_date]&.slice(0, 4),
          "reason" => generate_personalized_reason(candidate),
          "genres" => candidate[:genres],
          "tmdb" => candidate
        }
      end
    end

    filtered.first(3)
  end
end
