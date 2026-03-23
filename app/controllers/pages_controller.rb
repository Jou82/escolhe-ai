class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:home]
  def home
  end

  def profile
  end

  def update_profile
    platforms = params[:streaming_platforms] || []
    avatar = params.dig(:user, :avatar)

    attrs = { streaming_platforms: platforms.reject(&:blank?) }
    attrs[:avatar] = avatar if avatar.present?

    current_user.update(attrs)
    render json: { success: true }
  end
end
