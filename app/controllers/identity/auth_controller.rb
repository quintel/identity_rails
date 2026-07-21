# frozen_string_literal: true

module Identity
  # Starts and ends a session with the identity provider.
  #
  # There is no OAuth callback here any more. Under the shared session cookie the provider's own
  # login step sets the cookie on the parent domain, so by the time the visitor is back in this app
  # they are already signed in — the authorization-code round-trip existed only to build a per-app
  # session that no longer exists. Signing in is therefore a plain redirect to the provider,
  # carrying the page to return to.
  class AuthController < ApplicationController
    # Sends the visitor to the provider's sign-in page.
    #
    # A visitor can also arrive here already holding a valid session: the layout's recovery probe
    # slides a lapsed session and reloads, by which point they are signed in. Send them on to where
    # they were headed rather than bouncing them to the provider for nothing.
    def sign_in
      return redirect_to(return_to_url) if signed_in?

      redirect_to(identity_sign_in_url(return_to: return_to_url), allow_other_host: true)
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

    # Where to send the visitor once they are signed in, as an absolute URL: the provider is on
    # another host and can only redirect back here with a full URL.
    def return_to_url
      path = return_to_path(main_app.root_path)
      path.start_with?('http://', 'https://') ? path : "#{Identity.config.client_uri}#{path}"
    end

    # Builds an RP-initiated logout URL. Passes the client id and a post-logout redirect.
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
