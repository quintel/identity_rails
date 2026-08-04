# frozen_string_literal: true

module Identity
  # Starts and ends a session with the identity provider.
  class AuthController < ApplicationController
    # Sends the visitor to the provider's sign-in page.
    #
    # A visitor can also arrive here already holding a valid session: the layout's recovery probe
    # slides a lapsed session and reloads, by which point they are signed in. Send them on to where
    # they were headed.
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
    # another host and can only redirect back here with a full URL. return_to_path always yields a
    # path — it is stored as request.fullpath, and falls back to a route helper.
    def return_to_url
      "#{Identity.config.client_uri}#{return_to_path(main_app.root_path)}"
    end

    # Passes where to send the visitor once the provider has ended the session. The provider
    # validates it against the ETM app origins it serves.
    def logout_url
      uri = URI.parse(Identity.discovery_config[:end_session_endpoint])
      uri.query = { post_logout_redirect_uri: "#{Identity.config.client_uri}/" }.to_query

      uri.to_s
    end
  end
end
