class SessionMoviesController < ApplicationController
  before_action :authenticate_user!

  def show
    @session_record = current_user.sessions.find(params[:movie_session_id])
    @recommendations = @session_record.recommendations || []

    @rec_data = @recommendations.find { |rec| rec.dig("tmdb", "tmdb_id").to_s == params[:id].to_s }

    if @rec_data.nil?
      redirect_to movie_session_path(@session_record), alert: "Filme não encontrado." and return
    end
  end
end
