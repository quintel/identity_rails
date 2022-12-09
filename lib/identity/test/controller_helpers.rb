# frozen_string_literal: true

module Identity
  module Test
    # Helper methods for controller tests.
    module ControllerHelpers
      def self.included(*)
        raise 'Identity::Test::ControllerHelpers can only be used with RSpec' unless defined?(RSpec)
      end

      def sign_in(user)
        allow(controller).to receive(:identity_session_attributes).and_return(
          issuer: Identity.config.issuer,
          user: user.identity_user.dump,
          access_token: {
            access_token: "access_#{SecureRandom.base58}",
            refresh_token: "refresh_#{SecureRandom.base58}",
            expires_at: nil
          }
        )
      end
    end
  end
end
