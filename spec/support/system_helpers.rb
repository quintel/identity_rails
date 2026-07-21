# frozen_string_literal: true

require 'identity/test/system_helpers'

# Provides helpers for system specs.
module SystemHelpers
  include Identity::Test::SystemHelpers

  # Signs in as a user, the way the provider does: by placing a valid shared session cookie in the
  # browser. There is no in-app sign-in flow to drive.
  def sign_in
    identity_session_cookie(mock_identity_user_sign_in)
  end
end
