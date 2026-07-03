require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.new(email: "test@example.com", password: "password123")
    @user.skip_terms_validation!
    @user.terms_accepted_at = Time.current
    @user.save!
  end

  test "should destroy account with correct password" do
    sign_in @user
    assert_difference("User.count", -1) do
      delete destroy_account_path, params: { current_password: "password123" }
    end
    assert_redirected_to root_path
    assert_equal "Sua conta e todos os dados associados foram permanentemente deletados.", flash[:notice]
  end

  test "should not destroy account with incorrect password" do
    sign_in @user
    assert_no_difference("User.count") do
      delete destroy_account_path, params: { current_password: "wrong" }
    end
    assert_redirected_to profile_path
    assert_equal "Senha incorreta. Conta não foi excluída.", flash[:alert]
  end

  test "should redirect if not authenticated" do
    delete destroy_account_path, params: { current_password: "password123" }
    assert_redirected_to new_user_session_path
  end

  test "should sign out user after successful deletion" do
    sign_in @user
    delete destroy_account_path, params: { current_password: "password123" }
    follow_redirect!
    assert_nil @request.session["warden.user.user.key"]
  end
end
