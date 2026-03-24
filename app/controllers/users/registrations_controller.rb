class Users::RegistrationsController < Devise::RegistrationsController

  def update
    if current_user.update_with_password(account_update_params)
      bypass_sign_in(current_user)

      message = if account_update_params[:email].present? && account_update_params[:password].blank?
        "E-mail atualizado com sucesso!"
      elsif account_update_params[:password].present? && account_update_params[:email].blank?
        "Senha atualizada com sucesso!"
      else
        "Perfil atualizado com sucesso!"
      end

      redirect_to profile_path, notice: message
    else
      redirect_to profile_path, alert: current_user.errors.full_messages.first
    end
  end
end
