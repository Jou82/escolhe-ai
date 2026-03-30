class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  layout :devise_layout

  private

  def devise_layout
    devise_controller? ? "devise" : "application"
  end

  def after_sending_reset_password_instructions_path_for(_resource_name)
    root_path
  end
end
