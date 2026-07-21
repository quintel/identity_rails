# frozen_string_literal: true

module Identity
  module Test
    # Provides helpers for system and request specs.
    #
    # There is no sign-in flow for a host app's specs to drive: the provider owns the login form and
    # mints the shared session cookie. What a host app needs is a validly-signed cookie and a JWKS
    # that Identity::TokenDecoder will accept — which is what these helpers set up.
    module SystemHelpers
      TEST_SIGNING_KEY = OpenSSL::PKey::RSA.new(2048)
      TEST_KID = 'identity-test'

      # Public: Builds a signed session token for a regular user and stubs the provider's JWKS so
      # Identity::TokenDecoder accepts it. Returns the raw JWT; pass it to #identity_session_cookie
      # in a system spec, or set it as a cookie directly in a request spec.
      def mock_identity_user_sign_in(**kwargs)
        mock_identity_sign_in(**kwargs)
      end

      # Public: As above, for a user holding the admin role.
      def mock_identity_admin_sign_in(**kwargs)
        mock_identity_sign_in(roles: %w[user admin], **kwargs)
      end

      def mock_identity_sign_in(
        id: SecureRandom.random_number(1e10.to_i),
        name: 'John Doe',
        email: 'hello@example.org',
        roles: ['user'],
        expires_at: 1.hour.from_now
      )
        allow(Identity::TokenDecoder).to receive(:jwk_set).and_return(
          'keys' => [JWT::JWK.new(TEST_SIGNING_KEY.public_key, TEST_KID).export]
        )

        sign_test_jwt(id: id, name: name, email: email, roles: roles, expires_at: expires_at)
      end

      # Public: Places the token in the browser's cookie jar, as the provider would have done during
      # its own login step. Capybara has no cross-driver cookie API, so this covers rack_test (the
      # driver these specs use) and raises loudly rather than silently doing nothing elsewhere.
      def identity_session_cookie(token)
        browser = page.driver.browser

        unless browser.respond_to?(:rack_mock_session)
          raise "identity_session_cookie supports the rack_test driver; got #{browser.class}"
        end

        browser.rack_mock_session.cookie_jar[Identity.config.session_cookie_name] = token
      end

      private

      def sign_test_jwt(id:, name:, email:, roles:, expires_at:)
        payload = {
          iss: Identity.config.issuer,
          aud: [Identity.config.client_uri],
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
