# app/services/recommendation_pipeline.rb
class RecommendationPipeline
  MAX_RETRIES = 2
  TMDB_TIMEOUT = 12
  ANTHROPIC_TIMEOUT = 20

  def initialize(movies, user = nil)
    @movies = movies
    @user = user
  end

  def call
    candidates = fetch_candidates_guaranteed
    # Garantir que candidates seja um array
    candidates ||= []
    if candidates.empty?
      Rails.logger.error "❌ Nenhum candidato encontrado. Abortando pipeline."
      return { analysis: nil, recommendations: [] }
    end

    platform_movies = []
    rent_buy_movies = []
    already_recommended = []
    retries = 0

    # Prioridade: tentar obter 3 filmes da plataforma
    while platform_movies.size < 3 && retries <= MAX_RETRIES * 2
      current_candidates = remaining_candidates(candidates, already_recommended)
      break if current_candidates.empty?

      ai_result = fetch_ai_guaranteed(current_candidates)
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
        else
          if movie.dig("tmdb", :streaming)&.any? ||
             movie.dig("tmdb", :rent)&.any? ||
             movie.dig("tmdb", :buy)&.any?
            rent_buy_movies << movie unless rent_buy_movies.any? { |m| m["title"] == movie["title"] }
          end
        end
      end

      retries += 1
    end

    # FASE 2: se ainda não temos 3 filmes da plataforma, busca diretamente
    if user_has_platforms? && platform_movies.size < 3
      Rails.logger.info "🎯 Buscando filmes nas plataformas: #{user_platforms.join(', ')}"

      user_platforms.each do |platform|
        platform_candidates = TmdbService.discover_by_single_platform(platform, already_recommended, limit: 20)

        platform_candidates.each do |candidate|
          tmdb_data = TmdbService.new(candidate[:title], candidate[:release_date]&.slice(0, 4)).call
          next unless tmdb_data

          streaming_match = tmdb_data[:streaming]&.any? { |s| user_platforms.include?(s[:name]) }
          rent_match = tmdb_data[:rent]&.any? { |s| user_platforms.include?(s[:name]) }
          buy_match = tmdb_data[:buy]&.any? { |s| user_platforms.include?(s[:name]) }

          if streaming_match || rent_match || buy_match
            # Inclui os gêneros do filme (se disponíveis)
            genres = tmdb_data[:genres] || []
            movie = {
              "title" => candidate[:title],
              "original_title" => candidate[:original_title] || candidate[:title],
              "year" => candidate[:release_date]&.slice(0, 4)&.to_i || 2024,
              "reason" => nil,  # será preenchido depois
              "genres" => genres,
              "tmdb" => tmdb_data,
              "_type" => "platform"
            }
            platform_movies << movie unless platform_movies.any? { |m| m["title"] == movie["title"] }
            break if platform_movies.size >= 3
          end
        end
        break if platform_movies.size >= 3
      end
    end

    # FASE 3: se ainda não temos 1 filme para alugar/comprar (caso precise complementar)
    if user_has_platforms? && rent_buy_movies.size < 1
      Rails.logger.info "🎯 Buscando filmes para alugar/comprar"

      rent_buy_candidates = fetch_rent_buy_candidates(already_recommended + platform_movies.map { |m| m["title"] })

      rent_buy_candidates.each do |candidate|
        tmdb_data = TmdbService.new(candidate[:title], candidate[:release_date]&.slice(0, 4)).call
        next unless tmdb_data

        if tmdb_data[:rent].any? || tmdb_data[:buy].any?
          genres = tmdb_data[:genres] || []
          movie = {
            "title" => candidate[:title],
            "original_title" => candidate[:original_title] || candidate[:title],
            "year" => candidate[:release_date]&.slice(0, 4)&.to_i || 2024,
            "reason" => nil,
            "genres" => genres,
            "tmdb" => tmdb_data,
            "_type" => "rent_buy"
          }
          rent_buy_movies << movie unless rent_buy_movies.any? { |m| m["title"] == movie["title"] }
          break if rent_buy_movies.size >= 1
        end
      end
    end

    # ========== COMBINAÇÃO FINAL ==========
    if platform_movies.size >= 3
      available = platform_movies.first(3)
    elsif platform_movies.size >= 2
      available = platform_movies.first(2) + rent_buy_movies.first(1)
    else
      available = rent_buy_movies.first(3)
    end

    if available.size < 3
      available = (platform_movies + rent_buy_movies).first(3)
    end

    if available.empty?
      available = fetch_popular_fallback(already_recommended)
    end

    # ========== GARANTIR QUE O CAMPO "reason" SEJA PERSONALIZADO ==========
    final_recs = available.first(3).map do |movie|
      movie.delete("_type")
      if movie["reason"].blank?
        movie["reason"] = generate_personalized_reason(movie)
      end
      if movie["tmdb"].is_a?(Hash)
        movie["tmdb"] = movie["tmdb"].transform_keys(&:to_s)
        movie["tmdb"]["streaming"] = movie["tmdb"]["streaming"]&.map { |s| s.transform_keys(&:to_s) }
        movie["tmdb"]["rent"] = movie["tmdb"]["rent"]&.map { |r| r.transform_keys(&:to_s) }
        movie["tmdb"]["buy"] = movie["tmdb"]["buy"]&.map { |b| b.transform_keys(&:to_s) }
      end
      movie
    end

    {
      analysis: @analysis,
      recommendations: final_recs
    }
  end

  private

  def generate_personalized_reason(movie)
    begin
      client = Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY", nil))
      response = client.messages.create(
        model: "claude-haiku-4-5-20251001",
        max_tokens: 200,
        messages: [
          {
            role: "user",
            content: "Filmes favoritos do usuário: #{@movies.join(', ')}. " \
                     "Filme recomendado: #{movie['title']} (#{movie['year']}). " \
                     "Escreva em 1 frase por que esse filme combina com o gosto do usuário. " \
                     "Tom descontraído, como se fosse um amigo indicando. Responda só o texto, sem aspas."
          }
        ]
      )
      response.content.first.text.strip
    rescue => e
      Rails.logger.warn("Erro ao gerar reason: #{e.message}")
      "Recomendado baseado nos seus filmes favoritos: #{@movies.join(', ')}."
    end
  end

  def user_movies_genres_from_tmdb
    @user_movies_genres ||= begin
      genres = Set.new
      @movies.each do |title|
        tmdb_data = TmdbService.new(title).call
        if tmdb_data && tmdb_data[:genres]
          genres.merge(tmdb_data[:genres])
        end
      end
      genres.to_a
    rescue => e
      Rails.logger.warn "Não foi possível buscar gêneros dos filmes do usuário no TMDB: #{e.message}"
      []
    end
  end

  # ========== MÉTODOS AUXILIARES (mantidos inalterados) ==========
  def fetch_rent_buy_candidates(exclude_titles)
    retries = 0
    loop do
      begin
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
        wait_time = [2 ** retries, 10].min
        Rails.logger.warn "TMDB rent/buy tentativa #{retries} falhou: #{e.message}. Aguardando #{wait_time}s..."
        sleep(wait_time)
      end
    end
  end

  def fetch_popular_fallback(exclude_titles)
    retries = 0
    loop do
      begin
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
      rescue => e
        retries += 1
        wait_time = [2 ** retries, 10].min
        Rails.logger.warn "Fallback popular tentativa #{retries} falhou: #{e.message}. Aguardando #{wait_time}s..."
        sleep(wait_time)
        retry if retries < 3
        return []
      end
    end
  end

  def fetch_candidates_guaranteed
    retries = 0
    loop do
      begin
        Timeout.timeout(TMDB_TIMEOUT) do
          candidates = TmdbService.find_candidates(@movies, top_n: 30)
          return candidates if candidates.present?
        end
      rescue Timeout::Error, Errno::ECONNREFUSED, SocketError => e
        retries += 1
        wait_time = [2 ** retries, 10].min
        Rails.logger.warn "TMDB tentativa #{retries} falhou: #{e.message}. Aguardando #{wait_time}s..."
        sleep(wait_time)
      end
    end
  end

  def fetch_ai_guaranteed(candidates)
    retries = 0
    loop do
      begin
        Timeout.timeout(ANTHROPIC_TIMEOUT) do
          return AnthropicService.new(@movies, candidates, user_platforms).call
        end
      rescue Timeout::Error => e
        retries += 1
        wait_time = [2 ** retries, 10].min
        Rails.logger.warn "Anthropic tentativa #{retries} falhou: #{e.message}. Aguardando #{wait_time}s..."
        sleep(wait_time)
      rescue => e
        retries += 1
        wait_time = [2 ** retries, 10].min
        Rails.logger.warn "Anthropic erro #{retries}: #{e.message}. Aguardando #{wait_time}s..."
        sleep(wait_time)
      end
    end
  end

  def enrich_guaranteed(recommendations)
    retries = 0
    loop do
      begin
        Timeout.timeout(TMDB_TIMEOUT) do
          return TmdbService.enrich_recommendations(recommendations)
        end
      rescue Timeout::Error, Errno::ECONNREFUSED, SocketError => e
        retries += 1
        wait_time = [2 ** retries, 10].min
        Rails.logger.warn "TMDB enrich tentativa #{retries} falhou: #{e.message}. Aguardando #{wait_time}s..."
        sleep(wait_time)
      end
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
end
