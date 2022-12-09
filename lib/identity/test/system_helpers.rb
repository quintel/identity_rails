# frozen_string_literal: true

module Identity
  module Test
    # Provides helpers for system specs.
    module SystemHelpers
      # Public: Instructs OmniAuth to provide a fake authentication response where the user is a
      # user.
      def mock_omniauth_user_sign_in(**kwargs)
        mock_omniauth_sign_in(**kwargs)
      end

      # Public: Instructs OmniAuth to provide a fake authentication response where the user is an
      # administrator.
      def mock_omniauth_admin_sign_in(**kwargs)
        mock_omniauth_sign_in(roles: %w[user admin], **kwargs)
      end

      def mock_omniauth_sign_in(
        id: SecureRandom.random_number(1e10.to_i),
        name: 'John Doe',
        email: 'hello@example.org',
        roles: ['user'],
        expires_at: 1.hour.from_now
      )
        OmniAuth.config.test_mode = true
        OmniAuth.config.logger = Rails.logger

        OmniAuth.config.mock_auth[:identity] = OmniAuth::AuthHash.new(
          'provider' => 'identity',
          'uid' => id,
          'info' => {
            'email' => email,
            'nickname' => nil
          },
          'credentials' => {
            'token' => "test_access_#{SecureRandom.base58(16)}",
            'refresh_token' => "test_refresh_#{SecureRandom.base58(16)}",
            'expires_at' => expires_at.to_i,
            'expires' => true
          },
          'extra' => {
            'raw_info' => {
              'sub' => id,
              'email' => email,
              'roles' => roles,
              'name' => name
            }
          }
        )
      end
    end
  end
end
