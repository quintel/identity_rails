# frozen_string_literal: true

require 'dry-initializer'
require 'dry-types'
require 'oauth2'
require 'omniauth'
require 'omniauth-oauth2'
require 'omniauth/rails_csrf_protection'

# Helpers for interacting with the Identity authentication and authorization service.
module Identity
  extend Dry::Configurable

  setting :issuer, default: 'https://id.energytransitionmodel.com'
  setting :client_id
  setting :client_secret
  setting :scope, default: 'public'

  # Returns the configured OAuth2 client.
  #
  # @return [OAuth2::Client]
  def self.oauth_client
    @oauth_client ||= OAuth2::Client.new(
      config.client_id,
      config.client_secret,
      site: config.issuer
    )
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
end

require_relative 'identity/controller_helpers'
require_relative 'identity/engine'
require_relative 'identity/errors'
require_relative 'identity/omniauth/strategy'
require_relative 'identity/serializer'
require_relative 'identity/session'
require_relative 'identity/user'
require_relative 'identity/version'
