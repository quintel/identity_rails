# frozen_string_literal: true

# Provides helpers for system specs.
module SystemHelpers
  # Public: Instructs OmniAuth to provide a fake authentication response where the user is a user.
  def mock_omniauth_user_sign_in
    mock_onmiauth_sign_in
  end

  # Public: Instructs OmniAuth to provide a fake authentication response where the user is an
  # administrator.
  def mock_omniauth_admin_sign_in
    mock_onmiauth_sign_in(roles: %w[user admin])
  end

  private

  def mock_onmiauth_sign_in(roles: ['user'], expires: 1.hour.from_now)
    OmniAuth.config.mock_auth[:identity] = OmniAuth::AuthHash.new(
      'provider' => 'identity',
      'uid' => SecureRandom.random_number(1e10.to_i),
      'info' => {
        'email' => 'hello@example.org',
        'name' => 'John Doe',
        'roles' => roles
      },
      'credentials' => {
        'token' => "test_access_#{SecureRandom.base58(16)}",
        'refresh_token' => "test_refresh_#{SecureRandom.base58(16)}",
        'expires_at' => expires.to_i,
        'expires' => true
      },
      'extra' => {}
    )
  end
end
