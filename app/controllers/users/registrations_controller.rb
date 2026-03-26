class Users::RegistrationsController < Devise::RegistrationsController

  def create
    build_resource(sign_up_params)
    resource.save
    if resource.persisted?
      sign_in(resource)
      redirect_to root_path, notice: "Conta criada com sucesso!"
    else
      redirect_to root_path, alert: resource.errors.full_messages.first
    end
  end

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

  private

  def account_update_params
    params.require(:user).permit(:email, :current_password, :password, :password_confirmation, :display_name)
  end

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
