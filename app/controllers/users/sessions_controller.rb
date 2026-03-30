module Users
  class SessionsController < Devise::SessionsController
    def create
      self.resource = warden.authenticate(auth_options)
      if resource
        sign_in(resource_name, resource)
        redirect_to root_path, notice: "Login realizado com sucesso!"
      else
        redirect_to root_path, alert: "E-mail ou senha incorretos."
      end
    end
  end
end
