class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]
  def home
  end

  def profile
  end

  def update_profile
    platforms = params[:streaming_platforms] || []
    current_user.update(streaming_platforms: platforms.reject(&:blank?))
    render json: { success: true }
  end
end
