class RecommendationPipeline
  MAX_RETRIES = 5
  TMDB_TIMEOUT = 25
  ANTHROPIC_TIMEOUT = 45

  def initialize(movies, user = nil)
    @movies = movies
    @user = user
  end

  def call
    candidates = fetch_candidates_guaranteed

    # 🔥 Separa os filmes por tipo
    platform_movies = []
    rent_buy_movies = []
    already_recommended = []
    retries = 0

    while (platform_movies.size < 2 || rent_buy_movies.size < 1) && retries <= MAX_RETRIES * 2
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

          # Filme na plataforma do usuário
          if streaming_match || rent_match || buy_match
            movie["_type"] = "platform"
            platform_movies << movie unless platform_movies.any? { |m| m["title"] == movie["title"] }
          # Aluguel/compra em qualquer plataforma
          elsif movie.dig("tmdb", :rent)&.any? || movie.dig("tmdb", :buy)&.any?
            movie["_type"] = "rent_buy"
            rent_buy_movies << movie unless rent_buy_movies.any? { |m| m["title"] == movie["title"] }
          end
        else
          # Se não tem plataformas, aceita qualquer opção
          if movie.dig("tmdb", :streaming)&.any? ||
             movie.dig("tmdb", :rent)&.any? ||
             movie.dig("tmdb", :buy)&.any?
            rent_buy_movies << movie unless rent_buy_movies.any? { |m| m["title"] == movie["title"] }
          end
        end
      end

      retries += 1
    end

    # 🔥 FASE 2: Se não tem 2 filmes na plataforma, busca especificamente
    if user_has_platforms? && platform_movies.size < 2
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
            movie = {
              "title" => candidate[:title],
              "original_title" => candidate[:original_title] || candidate[:title],
              "year" => candidate[:release_date]&.slice(0, 4)&.to_i || 2024,
              "reason" => "Disponível em #{platform}",
              "genres" => [],
              "tmdb" => tmdb_data,
              "_type" => "platform"
            }
            platform_movies << movie unless platform_movies.any? { |m| m["title"] == movie["title"] }
            break if platform_movies.size >= 2
          end
        end
        break if platform_movies.size >= 2
      end
    end

    # 🔥 FASE 3: Se não tem 1 filme para alugar/comprar, busca especificamente
    if user_has_platforms? && rent_buy_movies.size < 1
      Rails.logger.info "🎯 Buscando filmes para alugar/comprar"

      rent_buy_candidates = fetch_rent_buy_candidates(already_recommended + platform_movies.map { |m| m["title"] })

      rent_buy_candidates.each do |candidate|
        tmdb_data = TmdbService.new(candidate[:title], candidate[:release_date]&.slice(0, 4)).call
        next unless tmdb_data

        if tmdb_data[:rent].any? || tmdb_data[:buy].any?
          movie = {
            "title" => candidate[:title],
            "original_title" => candidate[:original_title] || candidate[:title],
            "year" => candidate[:release_date]&.slice(0, 4)&.to_i || 2024,
            "reason" => "Disponível para alugar ou comprar",
            "genres" => [],
            "tmdb" => tmdb_data,
            "_type" => "rent_buy"
          }
          rent_buy_movies << movie unless rent_buy_movies.any? { |m| m["title"] == movie["title"] }
          break if rent_buy_movies.size >= 1
        end
      end
    end

    # 🔥 COMBINA OS RESULTADOS: 2 da plataforma + 1 aluguel/compra
    available = platform_movies.first(2) + rent_buy_movies.first(1)

    # Se ainda não tem 3, completa com o que tiver
    if available.size < 3
      available = (platform_movies + rent_buy_movies).first(3)
    end

    final_recs = available.first(3).map do |movie|
      movie.delete("_type")
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
    candidates.reject { |c| already_recommended.include?(c[:title]) }
  end

  def user_has_platforms?
    @user&.streaming_platforms&.any?
  end

  def user_platforms
    @user&.streaming_platforms || []
  end
end
