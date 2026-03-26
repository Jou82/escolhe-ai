class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  protected

  def after_sending_reset_password_instructions_path_for(resource_name)
    root_path
  end


end
