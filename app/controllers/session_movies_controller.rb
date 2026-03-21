class SessionMoviesController < ApplicationController
  before_action :authenticate_user!

  def show
    #@session = Session.find(params[:session_id])
    #@movie   = Movie.find(params[:id])
    #@genres  = @movie.genres
    #@like    = Like.find_by(session: @session, movie: @movie)
  end
end
