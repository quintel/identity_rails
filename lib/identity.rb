# frozen_string_literal: true

require 'dry-initializer'
require 'dry-types'
require 'oauth2'
require 'omniauth'
require 'omniauth_openid_connect'
require 'omniauth/rails_csrf_protection'

# Helpers for interacting with the Identity authentication and authorization service.
module Identity
  extend Dry::Configurable

  # The Identity service's base URL.
  setting :issuer, default: 'https://engine.energytransitionmodel.com'

  # The client ID to use when authenticating with the Identity service.
  setting :client_id

  # The client secret to use when authenticating with the Identity service.
  setting :client_secret

  # The base URL (protocol and hostname) of the application. This is used to construct the redirect
  # URL for the Identity service.
  setting :client_uri

  # The scopes to request when authenticating.
  setting :scope, default: 'public'

  # A proc to call after a successful sign-in. The proc will be passed the Identity::Session object.
  setting :on_sign_in

  # Returns the configured OAuth2 client.
  #
  # @return [OAuth2::Client]
  def self.oauth_client
    OpenIDConnect::Client.new(client_options)
  end

  # Creates an OAuth2::AccessToken using the current client and credentials returned by OmniAuth.
  def self.access_token(credentials)
    OAuth2::AccessToken.new(
      Identity.oauth_client,
      credentials['token'],
      expires_at: credentials['expires_at'],
      refresh_token: credentials['refresh_token']
    )
  end

  # Returns the OIDC client options.
  def self.client_options
    issuer = URI.parse(Identity.config.issuer)

    {
      port: issuer.port,
      scheme: issuer.scheme,
      host: issuer.host,
      identifier: Identity.config.client_id,
      secret: Identity.config.client_secret,
      redirect_uri: "#{Identity.config.client_uri}/auth/identity/callback"
    }
  end
end

require_relative 'identity/controller_helpers'
require_relative 'identity/engine'
require_relative 'identity/errors'
require_relative 'identity/serializer'
require_relative 'identity/session'
require_relative 'identity/user'
require_relative 'identity/version'
