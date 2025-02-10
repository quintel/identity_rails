# frozen_string_literal: true

module Identity
  # Handles OAuth2 callbacks and failures.
  class AuthController < ApplicationController
    def sign_in; end

    def callback
      id_session = Identity::Session.from_omniauth(
        request.env['omniauth.auth']['credentials'],
        request.env['omniauth.auth']['extra']['raw_info'],
        initiated_session_hash: initiated_session_attributes || {}
      )

      # Only rotate if this is the first of the sisters to start a session.
      rotate_session unless initiated_session_attributes

      session[IDENTITY_SESSION_KEY] = id_session.dump

      id_session.signal_sister_set_up unless initiated_session_attributes

      Identity.config.on_sign_in&.call(id_session)

      redirect_to(return_to_path(main_app.root_path))
    end

    def failure; end

    def sign_out
      return redirect_to(main_app.root_path) unless signed_in?

      # Resetting the session will remove the token, which we need to generate the logout URL.
      provider_logout_url = logout_url

      reset_session

      flash[:notice] = 'You have been signed out.'
      redirect_to provider_logout_url, allow_other_host: true
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
      uri = URI.parse(Identity.discovery_config.end_session_endpoint)
      uri.query = { access_token: identity_session.access_token.token }.to_query

      uri.to_s
    end

    def initiated_session_attributes
      session[IDENTITY_SESSION_KEY]
    end
  end
end
