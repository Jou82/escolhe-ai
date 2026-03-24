class Users::RegistrationsController < Devise::RegistrationsController

  def update
    if current_user.update_with_password(account_update_params)
      bypass_sign_in(current_user)
      redirect_to profile_path, notice: "Senha atualizada com sucesso!"

    else
      redirect_to profile_path, alert: current_user.errors.full_messages.first

    end
  end

  private

  def account_update_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
