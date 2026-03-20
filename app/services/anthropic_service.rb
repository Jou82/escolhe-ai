# app/services/anthropic_service.rb
class AnthropicService
  class RecommendationError < StandardError; end

  def initialize(movies, candidates = [])
    @movies = movies
    @candidates = candidates
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
    @client ||= Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY", nil))
  end

  def system_prompt
    <<~PROMPT
      Você é um crítico de cinema especialista e conhecedor do catálogo atual
      das plataformas de streaming no Brasil: Netflix, Globoplay, Prime Video,
      HBO Max (Max), Disney+, Apple TV+, Paramount+, MUBI, Telecine,
      Crunchyroll, Claro tv+, Star+ e Looke.

      ## SUA TAREFA

      1. Analise os filmes favoritos do usuário
      2. Identifique padrões de gosto: gênero, tom, temas, ritmo narrativo,
         estilo visual, abordagem de direção e época preferida
      3. #{@candidates.any? ? 'Escolha os 3 MELHORES filmes da lista de candidatos pré-selecionados' : 'Recomende 3 filmes que EXISTEM no catálogo atual de streaming no Brasil'}

      ## COMO ANALISAR

      Para cada filme, avalie estas 5 dimensões (que dados numéricos não capturam):

      1. **TEMAS E MENSAGENS**: Temas profundos em comum com os filmes do usuário
         (ex: fragmentação de identidade, crítica social, dilemas morais)
      2. **TOM E ATMOSFERA**: Compatibilidade de vibe/mood
         (ex: sombrio, contemplativo, tenso, esperançoso, neo-noir)
      3. **COMPLEXIDADE NARRATIVA**: Nível de complexidade compatível
         (ex: não-linear, múltiplas camadas, twist, narrador não-confiável)
      4. **APELO EMOCIONAL**: Que tipo de emoção provoca e se é compatível
         (ex: desconforto existencial, catarse, nostalgia, admiração)
      5. **ESTILO DE DIREÇÃO**: Abordagem cinematográfica similar
         (ex: uso de silêncio, edição frenética, fotografia naturalista)

      ## FORMATO DE RESPOSTA

      Responda APENAS com JSON válido, sem nenhum texto antes ou depois.
      Use exatamente esta estrutura:

      #{json_template}

      ## REGRAS OBRIGATÓRIAS

      - Recomende exatamente 3 filmes, nem mais nem menos
      - NUNCA recomende filmes que o usuário já listou
      - Priorize filmes que conectam com MÚLTIPLOS filmes do usuário
      - Evite o óbvio: se o usuário provavelmente já viu, perca pontos
      - Varie os gêneros — não recomende 3 filmes do mesmo tipo
      - NUNCA recomende sequências, pré-sequências ou spin-offs dos filmes que o usuário listou (ex: se listou Batman Begins, não recomende O Cavaleiro das Trevas)
      - Misture filmes brasileiros e internacionais quando fizer sentido
      - Inclua o título original quando for filme estrangeiro
      - Responda tudo em português brasileiro
      #{candidates_rules}
    PROMPT
  end

  # JSON template montado como hash Ruby → sempre válido
  def json_template
    rec = {
      "title" => "Título do Filme em Português",
      "original_title" => "Título Original (se for estrangeiro)",
      "year" => 2020,
      "match_percentage" => 92,
      "reason" => "1 frase explicando por que esse filme combina com o gosto do usuário. Mencione conexões específicas com os filmes escolhidos, referenciando as dimensões de análise. Fale como se estivesse indicando pra um amigo.",
      "match_dimensions" => %w[temas tom complexidade],
      "genres" => %w[Drama Thriller],
      "vibe" => "Uma frase curta que vende o filme"
    }

    # Campos extras conforme o modo
    if @candidates.any?
      rec["tmdb_id"] = 12_345
    else
      rec["streaming_hint"] = "Nome da plataforma onde provavelmente está disponível"
    end

    template = {
      "analysis" => "Análise precisa do perfil em até 500 caractéres em português BR.",
      "recommendations" => [rec]
    }

    JSON.pretty_generate(template)
  end

  def candidates_rules
    if @candidates.any?
      <<~RULES
        - Escolha SOMENTE filmes DA LISTA de candidatos fornecida
        - O match_percentage deve refletir a compatibilidade real (70-100)
      RULES
    else
      <<~RULES
        - Recomende SOMENTE filmes que você tem alta confiança de que estão
          no catálogo atual de streaming no Brasil. Se não tiver certeza,
          escolha outro filme
        - O match_percentage deve ser sempre 100
        - O campo streaming_hint é seu melhor palpite de onde o filme está,
          a confirmação real será feita por outra API
      RULES
    end
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
