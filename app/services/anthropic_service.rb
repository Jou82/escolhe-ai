class AnthropicService
  class RecommendationError < StandardError; end

  def initialize(movies, candidates = [], user_platforms = [])
    @movies = movies
    @candidates = candidates
    @user_platforms = user_platforms
  end

  def call
    response = client.messages.create(
      model: "claude-haiku-4-5-20251001",
      max_tokens: 600,
      system: system_prompt,
      messages: [
        { role: "user", content: user_prompt }
      ]
    )

    text = response.content.first.text
    text = text.gsub(/```json\n?/, "").gsub(/```\n?/, "").strip
    parsed = JSON.parse(text)

    validate!(parsed)
    parsed
  rescue JSON::ParserError => e
    raise RecommendationError, "Erro ao processar resposta da IA: #{e.message}"
  rescue Anthropic::Errors => e
    raise RecommendationError, "Erro de conexão com Anthropic: #{e.message}"
  end

  private

  def platform_instruction
    if @user_platforms.any?
      "O usuário possui APENAS estas plataformas: #{@user_platforms.join(', ')}. " \
        "Recomende SOMENTE filmes disponíveis nessas plataformas. Isso é OBRIGATÓRIO."
    else
      "Recomende filmes disponíveis em qualquer plataforma de streaming no Brasil."
    end
  end

  def client
    @client ||= Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY", nil))
  end

  def system_prompt
    <<~PROMPT
      Você é um especialista em cinema com conhecimento profundo de filmes
       brasileiros e internacionais. Analise os 3 filmes favoritos do usuário
       para identificar padrões de gosto: gênero, tom, temas, ritmo,
       estilo visual e abordagem de direção.

       #{platform_instruction}

       Responda APENAS com JSON válido, sem nenhum texto antes ou depois.
       Use exatamente esta estrutura:
       {
         "analysis": "Descrição breve do perfil de gosto do usuário (1 frase em português BR)",
         "recommendations": [
           {
             "title": "Título do Filme",
             "original_title": "Original Title (se diferente)",
             "year": 2020,
             "reason": "Por que esse filme combina com o gosto do usuário (1 frase)",
             "genres": ["Drama", "Thriller"]
           },
           {
             "title": "Título do Filme 2",
             "original_title": "Original Title 2",
             "year": 2019,
             "reason": "Motivo da recomendação",
             "genres": ["Comédia", "Drama"]
           },
           {
             "title": "Título do Filme 3",
             "original_title": "Original Title 3",
             "year": 2021,
             "reason": "Motivo da recomendação",
             "genres": ["Ação", "Ficção Científica"]
           }
         ]
       }

       Regras:
       - Recomende exatamente 3 filmes
       - NUNCA recomende filmes que o usuário já listou
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
    movies_text = @movies.map { |m| "- #{m}" }.join("\n")

    candidates_text = @candidates.map.with_index(1) do |c, i|
      overview = c[:overview].to_s.truncate(300)

      <<~CANDIDATE
        #{i}. #{c[:title]} (#{c[:release_date]&.slice(0, 4) || '?'}) — TMDB ID: #{c[:tmdb_id]}
           Nota: #{c[:vote_average]}/10 (#{c[:vote_count]} votos) | Freq: #{c[:frequency]}/3 | Score: #{c[:score]}
           Sinopse: #{overview}
      CANDIDATE
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
