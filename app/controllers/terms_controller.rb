class TermsController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :require_terms_acceptance

  def accept
  end

  def update
    if params[:accept_terms] == "1"
      current_user.update!(
        terms_accepted_at: Time.current,
        terms_version: User::CURRENT_TERMS_VERSION
      )
      redirect_to root_path, notice: "Termos aceitos. Bem-vindo(a)!"
    else
      flash.now[:alert] = "Você precisa aceitar os termos para continuar."
      render :accept, status: :unprocessable_entity
    end
  end
end
