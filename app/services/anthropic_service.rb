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
     Você é um especialista em cinema com conhecimento profundo de filmes
      brasileiros e internacionais. Analise os 3 filmes favoritos do usuário
      para identificar padrões de gosto: gênero, tom, temas, ritmo,
      estilo visual e abordagem de direção.

      Responda APENAS com JSON válido, sem nenhum texto antes ou depois.
      Use exatamente esta estrutura:
      {
        "analysis": "Descrição breve do perfil de gosto do usuário (2-3 frases em português BR)",
        "recommendations": [
          {
            "title": "Título do Filme",
            "original_title": "Original Title (se diferente)",
            "year": 2020,
            "reason": "Por que esse filme combina com o gosto do usuário (2-3 frases)",
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
