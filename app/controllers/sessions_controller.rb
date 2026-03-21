class SessionsController < ApplicationController
  def index
   @sessions = current_user.sessions.order(created_at: :desc)
  end

  def show
    @session_record = current_user.sessions.find(params[:id])
    @analysis = @session_record.analysis
    @recommendations = JSON.parse(@session_record.recommendations_data || "[]")
    @user_movies = @session_record.likes.where(suggestion: false).includes(:movie).map(&:movie)
    @suggested_movies = @session_record.likes.where(suggestion: true).includes(:movie).map(&:movie)
  end

  def new
  end
end
