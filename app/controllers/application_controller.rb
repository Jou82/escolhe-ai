class ApplicationController < ActionController::Base
  before_action :set_locale
  before_action :authenticate_user!
  before_action :require_terms_acceptance

  layout :devise_layout

  private

  def set_locale
    if params[:locale].present? && %w[pt en de].include?(params[:locale])
      I18n.locale = params[:locale]
    else
      I18n.locale = I18n.default_locale
    end
  end

  def devise_layout
    devise_controller? ? "devise" : "application"
  end

  def after_sending_reset_password_instructions_path_for(_resource_name)
    root_path
  end

  def require_terms_acceptance
    return unless user_signed_in?
    return if devise_controller?
    return if controller_name == "terms"
    return if controller_name == "pages" && %w[privacy terms].include?(action_name)
    return if current_user.terms_accepted_at.present?

    redirect_to accept_terms_path,
      alert: "Por favor, aceite os termos para continuar."
  end
end
