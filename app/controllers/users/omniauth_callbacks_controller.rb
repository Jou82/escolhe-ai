class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # Este método deve ter o mesmo nome do provider (google_oauth2)
  def google_oauth2
    @user = User.from_omniauth(request.env['omniauth.auth'])

    if @user.persisted?
      flash[:notice] = I18n.t 'devise.omniauth_callbacks.success', kind: 'Google'
      sign_in_and_redirect @user, event: :authentication
    else
      # Se der erro, guarda os dados na sessão e manda de volta pro cadastro
      session['devise.google_data'] = request.env['omniauth.auth'].except('extra')
      redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
    end
  end

  def failure
    redirect_to root_path, alert: "Falha na autenticação com o Google. Tente novamente."
  end
end
