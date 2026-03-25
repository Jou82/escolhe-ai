# app/services/anthropic_service.rb
class AnthropicService
  class RecommendationError < StandardError; end

  def initialize(movies, candidates = [], user_platforms = [], exclude_titles = [])
    @movies = movies
    @candidates = candidates
    @user_platforms = user_platforms
    @exclude_titles = exclude_titles
  end

  def call
    # 🔥 CACHE: Evita chamadas repetidas para a IA
    cache_key = "anthropic:#{@movies.sort.join('_')}"

    cached_result = Rails.cache.read(cache_key)
    if cached_result
      Rails.logger.info "💾 [ANTHROPIC CACHE] Usando recomendações em cache para: #{@movies.join(', ')}"
      return cached_result
    end

    Rails.logger.info "🤖 [ANTHROPIC] Chamando Claude Haiku para: #{@movies.join(', ')}"

    result = make_api_call

    # Salva no cache por 1 hora
    if result
      Rails.cache.write(cache_key, result, expires_in: 1.hour)
    end

    result
  end

  private

  def make_api_call
    # 🔥 Timeout reduzido para 10 segundos (antes era sem timeout)
    Timeout.timeout(10) do
      response = client.messages.create(
        model: "claude-haiku-4-5-20251001",
        max_tokens: 600,  # 🔥 Reduzido de 800 para 600
        system: system_prompt,
        messages: [
          { role: "user", content: user_prompt }
        ]
      )

      text = response.content.first.text
      text = text.gsub(/```json\n?/, "").gsub(/```\n?/, "").strip
      json_match = text.match(/\{.*\}/m)
      text = json_match[0] if json_match
      parsed = JSON.parse(text)

      validate!(parsed)
      parsed
    end
  rescue JSON::ParserError => e
    raise RecommendationError, "Erro ao processar resposta da IA: #{e.message}"
  rescue Anthropic::Errors => e
    raise RecommendationError, "Erro de conexão com Anthropic: #{e.message}"
  rescue Timeout::Error
    raise RecommendationError, "Tempo limite excedido (10s) - A IA demorou muito para responder"
  end

  def platform_instruction
    if @user_platforms.any?
      "O usuário possui APENAS estas plataformas: #{@user_platforms.join(', ')}. " \
      "Recomende SOMENTE filmes disponíveis nessas plataformas. Isso é OBRIGATÓRIO."
    else
      "Recomende filmes disponíveis em qualquer plataforma de streaming no Brasil."
    end
  end

  def format_exclude_titles
    titles = @exclude_titles.last(30)
    if titles.any?
      "\n\n**FILMES PROIBIDOS (NÃO RECOMENDAR SOB NENHUMA HIPÓTESE):** #{titles.join(', ')}"
    else
      ""
    end
  end

  def client
    @client ||= Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY", nil))
  end

  def system_prompt
    # 🔥 PROMPT OTIMIZADO: Mais enxuto e direto
    <<~PROMPT
      Especialista em cinema. Analise os filmes favoritos e recomende exatamente 3 filmes.
      IMPORTANTE: Responda SOMENTE com o JSON. Não escreva nada antes ou depois. Comece diretamente com {.

      #{platform_instruction}
      #{format_exclude_titles}

      Responda APENAS com JSON:
      {"analysis":"perfil em 1 frase","recommendations":[{"title":"Título PT","original_title":"Title EN","year":2020,"reason":"motivo em 1 frase","genres":["Gênero"]}]}

       Regras:
         - NUNCA recomende sequências, prequelas ou filmes da mesma franquia dos filmes favoritos do usuário
         - Recomende exatamente 3 filmes
         - NUNCA recomende filmes que o usuário já listou
         - NUNCA recomende filmes listados em "FILMES PROIBIDOS"
         - Somente filmes disponíveis em streaming no Brasil
         - O motivo deve referenciar padrões específicos encontrados nos 3 filmes
         - Inclua o título original quando for filme estrangeiro
         - Responda tudo em português (BR)
         - NUNCA recomende filmes que não estejam disponíveis em streaming por assinatura no Brasil. Isso é uma regra absoluta.
    PROMPT
  end


  def user_prompt
    if @candidates.any?
      user_prompt_with_candidates
    else
      "Meus filmes favoritos são: #{@movies.join(', ')}"
    end
  end

  def user_prompt_with_candidates
    # 🔥 PROMPT OTIMIZADO: Candidatos mais compactos
    movies_text = @movies.map { |m| "- #{m}" }.join("\n")

    # Limita para 12 candidatos para reduzir tokens
    limited_candidates = @candidates.first(12)

    candidates_text = limited_candidates.map.with_index(1) do |c, i|
      if c[:score].to_f >= 40
        "#{i}. #{c[:title]} (#{c[:release_date]&.slice(0, 4) || '?'}) — TMDB ID: #{c[:tmdb_id]} | Nota: #{c[:vote_average]}/10 | Score: #{c[:score]}"
      else
        "#{i}. #{c[:title]} (#{c[:release_date]&.slice(0, 4) || '?'}) — Score: #{c[:score]}"
      end
    end.join("\n")

    <<~USER
      ## MEUS 3 FILMES FAVORITOS:
      #{movies_text}

      ## CANDIDATOS PRÉ-FILTRADOS (escolha os 3 melhores):
      #{candidates_text}
    USER
  end

  def validate!(parsed)
    unless parsed.is_a?(Hash) &&
           parsed["recommendations"].is_a?(Array) &&
           parsed["recommendations"].size == 3
      raise RecommendationError, "Resposta da IA não tem o formato esperado"
    end
  end
end
