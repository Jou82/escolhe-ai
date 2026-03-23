class AnthropicService
  class RecommendationError < StandardError; end

  def initialize(movies, candidates = [], user_platforms = [], exclude_titles = [])
    @movies = movies
    @candidates = candidates
    @user_platforms = user_platforms
    @exclude_titles = exclude_titles
  end

  def call
    response = client.messages.create(
      model: "claude-haiku-4-5-20251001",
      max_tokens: 800, # Aumentado de 400 para 800 para garantir resposta completa
      system: system_prompt,
      messages: [
        { role: "user", content: user_prompt }
      ]
    )

    text = response.content.first.text

    # Log da resposta bruta para debug
    Rails.logger.info "=" * 80
    Rails.logger.info "RESPOSTA BRUTA DO CLAUDE:"
    Rails.logger.info text
    Rails.logger.info "=" * 80

    parsed = parse_response(text)
    validate!(parsed)
    parsed
  rescue JSON::ParserError => e
    Rails.logger.error "ERRO DE PARSE: #{e.message}"
    Rails.logger.error "TEXTO QUE FALHOU: #{text.inspect}"
    raise RecommendationError, "Erro ao processar resposta da IA: #{e.message}. Resposta recebida: #{text[0..200]}..."
  rescue Anthropic::Errors => e
    raise RecommendationError, "Erro de conexão com Anthropic: #{e.message}"
  end

  private

  def parse_response(text)
    # Remove marcações de markdown
    cleaned = text.strip
    cleaned = cleaned.gsub(/```json\s*/i, '')
    cleaned = cleaned.gsub(/```\s*/, '')
    cleaned = cleaned.strip

    # Tenta extrair o JSON se houver texto antes/depois
    if cleaned.match(/\{.*\}/m)
      cleaned = cleaned.match(/\{.*\}/m)[0]
    end

    # Tenta fazer o parse
    begin
      JSON.parse(cleaned)
    rescue JSON::ParserError => first_error
      Rails.logger.warn "Primeiro parse falhou: #{first_error.message}"
      Rails.logger.warn "Tentando reparar o JSON..."

      # Tenta reparar JSON truncado
      repaired = try_repair_json(cleaned)

      if repaired
        begin
          return JSON.parse(repaired)
        rescue JSON::ParserError => second_error
          Rails.logger.error "Parse reparado também falhou: #{second_error.message}"
        end
      end

      # Se tudo falhar, levanta o erro original
      raise first_error
    end
  end

  def try_repair_json(text)
    # Tenta fechar strings não fechadas
    # Isso é um reparo básico para JSON truncado
    lines = text.lines
    last_line = lines.last.to_s

    # Se a última linha tem aspas abertas, fecha
    if last_line.count('"').odd?
      last_line = last_line + '"'
      lines[-1] = last_line
    end

    # Tenta fechar o objeto se estiver truncado
    repaired = lines.join
    unless repaired.strip.end_with?('}')
      repaired = repaired + '}'
    end

    # Verifica se o JSON está minimamente válido
    begin
      JSON.parse(repaired)
      return repaired
    rescue
      return nil
    end
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
    if @exclude_titles.any?
      "\n\n**FILMES PROIBIDOS (NÃO RECOMENDAR SOB NENHUMA HIPÓTESE):** #{@exclude_titles.join(', ')}"
    else
      ""
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

     **IMPORTANTE**: Responda APENAS com JSON válido, sem nenhum texto antes ou depois.
     Não use markdown, não use ```json, apenas o JSON puro.

     **NOMES DOS CAMPOS OBRIGATÓRIOS EM INGLÊS:**
     Use EXATAMENTE estes nomes de campos:
     {
       "analysis": "Descrição breve do perfil de gosto do usuário (1 frase em português BR)",
       "recommendations": [
         {
           "title": "Título do Filme",
           "original_title": "Original Title (se diferente, senão use o mesmo título)",
           "year": 2020,
           "reason": "Por que esse filme combina com o gosto do usuário (1 frase)",
           "genres": ["Drama", "Thriller"]
         }
       ]
     }

     **ATENÇÃO:**
     - O campo "analysis" é OBRIGATÓRIO e deve vir em português
     - O campo "recommendations" (plural, em inglês) é OBRIGATÓRIO
     - Dentro de cada recomendação, use "title", "original_title", "year", "reason", "genres"
     - "genres" deve ser um array de strings em português

     Regras:
     - Recomende exatamente 3 filmes
     - NUNCA recomende filmes que o usuário já listou
     - Somente filmes disponíveis em streaming no Brasil
     - O motivo deve referenciar padrões específicos encontrados nos 3 filmes
     - Responda tudo em português (BR)
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
