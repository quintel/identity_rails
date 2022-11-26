# frozen_string_literal: true

module Identity
  # Handles OAuth2 callbacks and failures.
  class AuthController < ApplicationController
    def sign_in; end

    def callback
      id_session = Identity::Session.from_omniauth(
        Identity.access_token(request.env['omniauth.auth']['credentials']),
        request.env['omniauth.auth']
      )

      rotate_session

      session[IDENTITY_SESSION_KEY] = id_session.dump
      redirect_to(return_to_path('/'))
    end

    def failure; end

    def sign_out
      return redirect_to('/') unless signed_in?

      reset_session

      flash[:notice] = 'You have been signed out.'
      redirect_to logout_url, allow_other_host: true
    end

    private

    # Creates a new session, retaining all the non-identity values from the current one. This gives
    # the visitor a new session_id after signing in, preventing a session fixation attack, while
    # keeping any other session values they may have.
    def rotate_session
      prev_session = session.to_h.except('identity', 'session_id')
      reset_session
      prev_session.each { |key, value| session[key.to_sym] = value }
    end

    def logout_url
      return_to = URI(request.url)
      return_to.path = '/'

      request_params = {
        return_to: return_to.to_s,
        client_id: Identity.config.client_id
      }

      uri = URI(Identity.config.issuer)
      uri.path = '/logout'
      uri.query = request_params.to_query

      uri.to_s
    end
  end
end
