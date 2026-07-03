module Users
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    # Este método deve ter o mesmo nome do provider (google_oauth2)
    def google_oauth2
      @user = User.from_omniauth(request.env['omniauth.auth'])

      if @user.persisted?
        sign_in @user, event: :authentication
        if @user.terms_accepted_at.present?
          redirect_to root_path, notice: I18n.t('devise.omniauth_callbacks.success', kind: 'Google')
        else
          redirect_to accept_terms_path,
            notice: "Antes de continuar, por favor aceite nossa Política de Privacidade e Termos de Uso."
        end
      else
        # Se der erro, guarda os dados na sessão e manda de volta pro cadastro
        session['devise.google_data'] = request.env['omniauth.auth'].except('extra').to_h
        redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
      end
    end

    def failure
      redirect_to root_path, alert: "Falha na autenticação com o Google. Tente novamente."
    end
  end
end
