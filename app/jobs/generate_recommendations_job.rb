# app/jobs/generate_recommendations_job.rb
class GenerateRecommendationsJob < ApplicationJob
  queue_as :default

  include ActionView::RecordIdentifier

  retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(user_id, movies_input, exclude_titles = [], session_id = nil)
    start_time = Time.current
    user = User.find(user_id)

    Rails.logger.info "🎬 [JOB] Iniciado em #{start_time}"
    Rails.logger.info "📽️  [INPUT] Filmes: #{movies_input.join(', ')}"
    Rails.logger.info "📊 Exclude limitado: #{exclude_titles.size} → #{exclude_titles.size} filmes"

    begin
      # Avisar que começou
      broadcast_status(user, "🔍 Buscando filmes similares...")

      pipeline_start = Time.current
      pipeline = RecommendationPipeline.new(movies_input, user, exclude_titles)
      result = pipeline.call
      pipeline_duration = (Time.current - pipeline_start).round(2)

      Rails.logger.info "⏱️  [PIPELINE] Demorou: #{pipeline_duration}s"

      # Avisar que está processando
      broadcast_status(user, "🤖 Gerando recomendações...")

      # 🔥 NOVO: Limitar candidatos para 15 (ANTES do Claude)
      if result[:candidates].present? && result[:candidates].size > 15
        original_size = result[:candidates].size
        result[:candidates] = result[:candidates].first(15)
        Rails.logger.info "🔍 Limitando candidatos: #{original_size} → #{result[:candidates].size}"
      end

      # ⚡ OTIMIZAÇÃO: Buscar dados do TMDB com cache
      if result[:recommendations].any?
        broadcast_status(user, "📡 Buscando detalhes dos filmes...")

        enrich_start = Time.current
        # Usando o novo método com cache (mais rápido!)
        result[:recommendations] = TmdbService.enrich_recommendations_with_cache(result[:recommendations])
        enrich_duration = (Time.current - enrich_start).round(2)
        Rails.logger.info "⏱️  [ENRICH] Demorou: #{enrich_duration}s"
      end

      save_start = Time.current

      if result[:recommendations].any?
        session_record = if session_id
                           user.sessions.find(session_id)
                         else
                           user.sessions.new
                         end

        session_record.analysis = result[:analysis]
        session_record.recommendations_data = result[:recommendations].to_json
        session_record.input_movies = movies_input
        session_record.status = 1 # 1 = completed
        session_record.error_message = nil
        session_record.save!

        # Bulk insert: filmes de input → likes com suggestion: false
        input_movie_ids = movies_input.map do |title|
          Movie.find_or_create_by!(title: title.strip).id
        end
        existing_input_likes = session_record.likes.where(suggestion: false, movie_id: input_movie_ids).pluck(:movie_id)
        new_input_likes = (input_movie_ids - existing_input_likes).map do |mid|
          { session_id: session_record.id, movie_id: mid, suggestion: false, created_at: Time.current, updated_at: Time.current }
        end
        Like.insert_all(new_input_likes) if new_input_likes.any?

        # Bulk insert: filmes recomendados → likes com suggestion: true
        rec_movie_ids = result[:recommendations].map do |rec|
          movie = Movie.find_or_create_by!(title: rec["title"]) do |m|
            m.release_year = rec["year"] || rec.dig("tmdb", "release_date")&.slice(0, 4)&.to_i
            m.synopsis = rec.dig("tmdb", "overview") || rec["reason"]
          end

          # Bulk insert de gêneros
          if rec["genres"].present?
            genre_ids = rec["genres"].map { |name| Genre.find_or_create_by!(name: name).id }
            existing_mg = MovieGenre.where(movie_id: movie.id, genre_id: genre_ids).pluck(:genre_id)
            new_mg = (genre_ids - existing_mg).map do |gid|
              { movie_id: movie.id, genre_id: gid, created_at: Time.current, updated_at: Time.current }
            end
            MovieGenre.insert_all(new_mg) if new_mg.any?
          end

          movie.id
        end

        existing_rec_likes = session_record.likes.where(suggestion: true, movie_id: rec_movie_ids).pluck(:movie_id)
        new_rec_likes = (rec_movie_ids - existing_rec_likes).map do |mid|
          { session_id: session_record.id, movie_id: mid, suggestion: true, created_at: Time.current, updated_at: Time.current }
        end
        Like.insert_all(new_rec_likes) if new_rec_likes.any?

        save_duration = (Time.current - save_start).round(2)
        total_duration = (Time.current - start_time).round(2)

        Rails.logger.info "💾 [SAVE] Demorou: #{save_duration}s"
        Rails.logger.info "✅ [JOB] Completou em: #{total_duration}s"

        # Alerta se demorar mais que 15 segundos
        if total_duration > 15
          Rails.logger.warn "⚠️  Job lento: #{total_duration}s - Verificar otimizações"
        end

        broadcast_completion(user, session_record)
      else
        handle_failure(session_id, user, "Não foi possível gerar recomendações no momento")
      end
    rescue StandardError => e
      Rails.logger.error "❌ [ERRO] #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      handle_failure(session_id, user, e.message)
      raise e
    end
  end

  private

  def handle_failure(session_id, user, message)
    if session_id
      session = user.sessions.find_by(id: session_id)
      if session
        session.status = 2 # 2 = failed
        session.error_message = message
        session.save!
        broadcast_error(user, message, session)
      end
    else
      broadcast_error(user, message)
    end
  end

  def broadcast_completion(user, session_record)
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user.id}_recommendations",
      target: "recommendations_container",
      partial: "movies/redirect",
      locals: { session_id: session_record.id }
    )
  end

  def broadcast_error(user, message, session = nil)
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user.id}_recommendations",
      target: "recommendations_container",
      partial: "shared/error",
      locals: { message: message, session: session }
    )
  end

  def broadcast_status(user, message)
    Turbo::StreamsChannel.broadcast_replace_to(
      "user_#{user.id}_recommendations",
      target: "recommendations_container",
      partial: "shared/loading",
      locals: { message: message }
    )
  end
end
