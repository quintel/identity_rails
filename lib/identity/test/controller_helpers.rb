# frozen_string_literal: true

module Identity
  module Test
    # Helper methods for controller tests.
    module ControllerHelpers
      def self.included(*)
        raise 'Identity::Test::ControllerHelpers can only be used with RSpec' unless defined?(RSpec)
      end

      # Stubs the controller as though the given user is already signed in via the shared JWT
      # session cookie (identity_user is the only thing derived from it), without needing a real
      # signed token or a round-trip to the provider. Sets both the top-level `roles` claim and the
      # `user.admin` flag, since consuming apps read the admin bit either way (Identity::User checks
      # `roles` first, falling back to `user.admin`; host apps' own User.from_jwt!-style methods
      # typically only check `user.admin`).
      def sign_in(user)
        identity_user = user.identity_user

        allow(controller).to receive(:identity_token).and_return(
          'sub' => identity_user.id,
          'roles' => identity_user.roles.to_a,
          'user' => {
            'email' => identity_user.email,
            'name' => identity_user.name,
            'admin' => identity_user.admin?
          }
        )
      end
    end
  end
end
