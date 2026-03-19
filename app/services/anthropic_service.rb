class AnthropicService
  class RecommendationError < StandardError; end

  def initialize(movies)
    @movies = movies
  end

  def call
    response = client.messages.create(
      model: "claude-haiku-4-5-20251001",
      max_tokens: 1024,
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
  rescue Anthropic::Error => e
    raise RecommendationError, "Erro de conexão com Anthropic: #{e.message}"
  end

  private

  def client
    @client ||= Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"])
  end

  def system_prompt
    <<~PROMPT
      Você é um especialista em cinema e no catálogo atual das plataformas
      de streaming disponíveis no Brasil: Netflix, Globoplay, Prime Video,
      HBO Max (Max), Disney+, Apple TV+, Paramount+, MUBI, Telecine,
      Crunchyroll, Claro tv+, Star+ e Looke.

      Sua tarefa:
      1. Analise os 3 filmes favoritos do usuário
      2. Identifique padrões de gosto: gênero, tom, temas, ritmo narrativo,
         estilo visual, abordagem de direção e época preferida
      3. Recomende 3 filmes que EXISTEM no catálogo atual de streaming no Brasil

      Responda APENAS com JSON válido, sem nenhum texto antes ou depois.
      Use exatamente esta estrutura:
      {
        "analysis": "Análise precisa do perfil: gêneros dominantes, ritmo preferido (lento/dinâmico), tipo de narrativa (linear/não-linear), temas recorrentes, e se o gosto tende a cinema autoral ou comercial. Máximo 3 frases em português BR.",
        "recommendations": [
          {
            "title": "Título do Filme em Português",
            "original_title": "Título Original (se for estrangeiro)",
            "year": 2020,
            "match_percentage": 92,
            "reason": "3-4 frases explicando por que esse filme combina com o gosto do usuário. Mencione conexões específicas com os filmes escolhidos: temas em comum, estilo de direção parecido, sensação semelhante, tom narrativo. Fale como se estivesse indicando pra um amigo.",
            "genres": ["Drama", "Thriller"],
            "vibe": "Uma frase curta que vende o filme (ex: 'Vai te prender do começo ao fim e te fazer repensar tudo')",
            "streaming_hint": "Nome da plataforma onde provavelmente está disponível"
          }
        ]
      }

      Regras obrigatórias:
      - Recomende exatamente 3 filmes, nem mais nem menos
      - NUNCA recomende filmes que o usuário já listou
      - Recomende SOMENTE filmes que você tem alta confiança de que estão
        no catálogo atual de streaming no Brasil. Se não tiver certeza,
        escolha outro filme. Prefira filmes populares e conhecidos que
        têm maior chance de estar disponíveis
      - O match_percentage deve ser sempre 100. Recomende apenas filmes com compatibilidade perfeita com o gosto do usuário
      - Varie os gêneros — não recomende 3 filmes do mesmo tipo
      - Misture filmes brasileiros e internacionais quando fizer sentido
      - Inclua o título original quando for filme estrangeiro
      - O campo streaming_hint é seu melhor palpite de onde o filme está,
        a confirmação real será feita por outra API
      - Responda tudo em português brasileiro
    PROMPT
  end

  def user_prompt
    "Meus filmes favoritos são: #{@movies.join(', ')}"
  end

  def validate!(parsed)
    unless parsed.is_a?(Hash) &&
      parsed["recommendations"].is_a?(Array) &&
      parsed["recommendations"].size == 3
      raise RecommendationError, "Resposta da IA não tem o formato esperado"
    end
  end
end
