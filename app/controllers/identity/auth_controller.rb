# frozen_string_literal: true

module Identity
  # Handles OAuth2 callbacks and failures.
  class AuthController < ApplicationController
    def start; end

    def callback
      id_session = Identity::Session.from_omniauth(
        Identity.access_token(request.env['omniauth.auth']['credentials']),
        request.env['omniauth.auth']
      )

      session[:identity] = id_session.dump

      redirect_to(return_to_path('/'))
    end

    def failure; end
  end
end
