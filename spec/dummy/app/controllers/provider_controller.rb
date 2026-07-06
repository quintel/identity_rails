# frozen_string_literal: true

# A controller which stubs some OAuth2 provider endpoints. In production, the provider (MyETM)
# clears the shared session cookie during its own logout; this mimics that so signing out behaves
# the same way in tests.
class ProviderController < ApplicationController
  def logout
    cookies.delete(Identity.config.session_cookie_name)
    redirect_to '/', allow_other_host: true
  end
end
