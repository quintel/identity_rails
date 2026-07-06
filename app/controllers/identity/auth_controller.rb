# frozen_string_literal: true

module Identity
  # Handles OAuth2 callbacks and failures.
  class AuthController < ApplicationController
    def sign_in; end

    # By the time this fires, the shared JWT session cookie is already set: the provider (MyETM)
    # sets it during its own login step, earlier in this same top-level navigation, on the same
    # parent domain. All that's left to do here is rotate the session (fixation hygiene) and return
    # the visitor to where they were headed.
    def callback
      rotate_session
      redirect_to(return_to_path(main_app.root_path))
    end

    def failure
      # A real OAuth error (e.g. the user denied the request): render the failure page.
    end

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

    # Builds an RP-initiated logout URL. Passes the client id and a post-logout redirect
    def logout_url
      uri = URI.parse(Identity.discovery_config.end_session_endpoint)
      uri.query = {
        client_id: Identity.config.client_id,
        post_logout_redirect_uri: "#{Identity.config.client_uri}/"
      }.to_query

      uri.to_s
    end
  end
end
