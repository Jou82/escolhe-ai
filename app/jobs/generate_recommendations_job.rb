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
        session_record.status = 1  # 1 = completed
        session_record.error_message = nil
        session_record.save!

        movies_input.each do |title|
          movie = Movie.find_or_create_by!(title: title.strip)
          session_record.likes.find_or_create_by!(movie: movie, suggestion: false)
        end

        result[:recommendations].each do |rec|
          movie = Movie.find_or_create_by!(title: rec["title"]) do |m|
            m.release_year = rec["year"] || rec.dig("tmdb", "release_date")&.slice(0, 4)&.to_i
            m.synopsis = rec.dig("tmdb", "overview") || rec["reason"]
          end

          if rec["genres"].present?
            rec["genres"].each do |genre_name|
              genre = Genre.find_or_create_by!(name: genre_name)
              MovieGenre.find_or_create_by!(movie: movie, genre: genre)
            end
          end

          session_record.likes.find_or_create_by!(movie: movie, suggestion: true)
        end

        save_duration = (Time.current - save_start).round(2)
        total_duration = (Time.current - start_time).round(2)

        Rails.logger.info "💾 [SAVE] Demorou: #{save_duration}s"
        Rails.logger.info "✅ [JOB] Completou em: #{total_duration}s"

        broadcast_completion(user, session_record)
      else
        handle_failure(session_id, user, "Não foi possível gerar recomendações no momento")
      end

    rescue => e
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
        session.status = 2  # 2 = failed
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
