# frozen_string_literal: true

module Identity
  module Test
    # Provides helpers for system specs.
    module SystemHelpers
      TEST_SIGNING_KEY = OpenSSL::PKey::RSA.new(2048)
      TEST_KID = 'identity-test'

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

      # Public: Simulates a user who already holds a valid shared JWT session cookie, as if MyETM
      # had already signed them in during an earlier step of the same top-level navigation. There is
      # no separate provider app in this test harness to set the cookie mid-navigation, so it is
      # applied as a side effect of the real sign-in callback (still exercising the real
      # rotate_session/redirect logic) rather than requiring a network round trip to a real provider.
      #
      # Returns the raw signed JWT.
      def mock_omniauth_sign_in(
        id: SecureRandom.random_number(1e10.to_i),
        name: 'John Doe',
        email: 'hello@example.org',
        roles: ['user'],
        expires_at: 1.hour.from_now
      )
        OmniAuth.config.test_mode = true
        OmniAuth.config.logger = Rails.logger

        OmniAuth.config.mock_auth[:identity] = OmniAuth::AuthHash.new('provider' => 'identity', 'uid' => id)

        token = sign_test_jwt(id: id, name: name, email: email, roles: roles, expires_at: expires_at)

        allow(Identity::TokenDecoder).to receive(:jwk_set).and_return(
          'keys' => [JWT::JWK.new(TEST_SIGNING_KEY.public_key, TEST_KID).export]
        )

        allow_any_instance_of(Identity::AuthController).to receive(:callback) do |controller|
          controller.instance_exec do
            rotate_session
            cookies[Identity.config.session_cookie_name] = token
            redirect_to(return_to_path(main_app.root_path))
          end
        end

        token
      end

      private

      def sign_test_jwt(id:, name:, email:, roles:, expires_at:)
        payload = {
          iss: Identity.config.issuer,
          aud: Identity.config.client_uri,
          sub: id.to_s,
          exp: expires_at.to_i,
          roles: roles,
          user: { email: email, name: name }
        }

        JWT.encode(payload, TEST_SIGNING_KEY, 'RS256', kid: TEST_KID)
      end
    end
  end
end
