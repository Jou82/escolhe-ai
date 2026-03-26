class Users::SessionsController < Devise::SessionsController

  def create
    # usa o método padrão do Devise para autenticar
    self.resource = resource_class.find_for_authentication(email: params[:user][:email])

    if self.resource&.valid_password?(params[:user][:password])
      sign_in(resource_name, resource)
      render json: { success: true, redirect: root_path }
    else
      render json: { success: false, error: "E-mail ou senha incorretos." }
    end
  end
end
