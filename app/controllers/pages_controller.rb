class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]
  def home
  end

  def profile
  end

  def update_profile
    platforms = params[:streaming_platforms] || []
    current_user.update(streaming_platforms: platforms.reject(&:blank?))
    flash[:notice] = "Plataformas atualizadas!"
    redirect_to profile_path
  end
end
