class AccountsController < ApplicationController
  before_action :authenticate_user!

  def destroy
    user = current_user
    user_has_password = user.encrypted_password.present? && user.provider.blank?

    if user_has_password
      unless user.valid_password?(params[:current_password])
        return redirect_to profile_path, alert: t("profile.danger_card.incorrect_password")
      end
    elsif user.provider.present?
      unless params[:email] == user.email
        return redirect_to profile_path, alert: t("profile.danger_card.incorrect_email_confirmation")
      end
    end

    sign_out(current_user)
    user.destroy!
    Rails.logger.info("Account deletion completed at #{Time.current}")

    redirect_to root_path, notice: t("profile.danger_card.account_deleted_success")
  end
end
