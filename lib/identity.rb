# frozen_string_literal: true

require 'dry-initializer'
require 'dry-types'
require 'dry-validation'
require 'faraday'
require 'omniauth'
require 'omniauth/rails_csrf_protection'
require 'omniauth_openid_connect'

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

  # Sets whether to validate the config when mounting the Rails engine. It's useful to disabling
  # this when, for example, building production images where the config is not yet available.
  setting :validate_config, default: true

  # Returns a Faraday connection to the Identity service.
  #
  # @return [Faraday::Connection]
  def self.http_client(access_token: nil)
    Faraday.new(url: Identity.config.issuer) do |f|
      f.request(:json)
      f.request(:authorization, 'Bearer', access_token) if access_token
      f.response(:raise_error)
      f.response(:json)
    end
  end

  # Returns the OpenID Connect discovery configuration for the Identity service.
  def self.discovery_config
    @discovery_config ||=
      OpenIDConnect::Discovery::Provider::Config.discover!(Identity.config.issuer)
  end
end

require_relative 'identity/access_token'
require_relative 'identity/config_validator'
require_relative 'identity/controller_helpers'
require_relative 'identity/engine'
require_relative 'identity/errors'
require_relative 'identity/serializer'
require_relative 'identity/session'
require_relative 'identity/user'
require_relative 'identity/version'
