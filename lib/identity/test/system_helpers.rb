# frozen_string_literal: true

module Identity
  module Test
    # Provides helpers for system and request specs.
    #
    # There is no sign-in flow for a host app's specs to drive: the provider owns the login form and
    # mints the shared session cookie. What a host app needs is a validly-signed cookie and a JWKS
    # that Identity::TokenDecoder will accept — which is what these helpers set up.
    module SystemHelpers
      TEST_KID = 'identity-test'

      # The keypair test tokens are signed with. Generated on first use, not at load time: this file
      # is required by every host app's spec suite, most of whose examples never sign a token, and
      # an RSA keygen is not free.
      def self.test_signing_key
        @test_signing_key ||= OpenSSL::PKey::RSA.new(2048)
      end

      # Public: Builds a signed session token for a regular user and stubs the provider's JWKS so
      # Identity::TokenDecoder accepts it. Returns the raw JWT; pass it to #identity_session_cookie
      # in a system spec, or set it as a cookie directly in a request spec.
      def mock_identity_user_sign_in(**kwargs)
        mock_identity_sign_in(**kwargs)
      end

      # Public: As above, for a user holding the admin role.
      def mock_identity_admin_sign_in(**kwargs)
        mock_identity_sign_in(admin: true, **kwargs)
      end

      def mock_identity_sign_in(
        id: SecureRandom.random_number(1e10.to_i),
        name: 'John Doe',
        email: 'hello@example.org',
        admin: false,
        expires_at: 1.hour.from_now
      )
        allow(Identity::TokenDecoder).to receive(:jwk_set).and_return(
          'keys' => [JWT::JWK.new(SystemHelpers.test_signing_key.public_key, TEST_KID).export]
        )

        sign_test_jwt(id: id, name: name, email: email, admin: admin, expires_at: expires_at)
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

      # Mints a token in the shape MyETM actually issues — see spec/fixtures/token_contract.json in
      # this gem. Notably there is no top-level `roles` claim: authorisation travels as the
      # `user.admin` boolean, and Identity::User derives roles from it.
      def sign_test_jwt(id:, name:, email:, admin:, expires_at:)
        payload = {
          iss: Identity.config.issuer,
          aud: [Identity.config.client_uri],
          sub: id.to_s,
          exp: expires_at.to_i,
          user: { id: id, email: email, name: name, admin: admin }
        }

        JWT.encode(payload, SystemHelpers.test_signing_key, 'RS256', kid: TEST_KID)
      end
    end
  end
end
