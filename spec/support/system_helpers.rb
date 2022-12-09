# frozen_string_literal: true

require 'identity/test/system_helpers'

# Provides helpers for system specs.
module SystemHelpers
  include Identity::Test::SystemHelpers

  # Signs in as a user.
  def sign_in
    mock_omniauth_user_sign_in

    visit('/')
    click_button('Sign in')
  end
end
