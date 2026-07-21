# frozen_string_literal: true

require 'dry-initializer'
require 'dry-types'
require 'dry-validation'
require 'faraday'
require 'openid_connect'

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

  # Optional URL (protocol and hostname) for the resource server to connect to
  setting :resource_uri

  # The scopes to request when authenticating.
  setting :scope, default: 'public'

  # Sets whether to validate the config when mounting the Rails engine. It's useful to disabling
  # this when, for example, building production images where the config is not yet available.
  setting :validate_config, default: true

  # Name of the parent-domain JWT session cookie. The provider (MyETM) mints it on login and every
  # ETM app reads it as the browser session: a self-contained identity JWT, verified locally by
  # TokenDecoder. Auto-sent same-site to ETEngine, it unifies browser-session and API-bearer auth.
  setting :session_cookie_name, default: 'etm_session'

  # Returns a Faraday connection to the Identity service, or the resource server.
  #
  # @return [Faraday::Connection]
  def self.http_client(access_token: nil, resource: false)
    uri = if resource && Identity.config.resource_uri.present?
      Identity.config.resource_uri
    else
      Identity.config.issuer
    end

    Faraday.new(url: uri) do |f|
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

require_relative 'identity/errors'
require_relative 'identity/config_validator'
require_relative 'identity/resource_server'
require_relative 'identity/token_decoder'
require_relative 'identity/controller_helpers'
require_relative 'identity/engine'
require_relative 'identity/user'
require_relative 'identity/version'

# Monkeypatches OpenIDConnect to keep the HTTP scheme instead of forcing HTTPS for discovery
# requests.
#
# See https://github.com/nov/openid_connect/issues/47#issuecomment-644799409
Module.new do
  attr_reader :scheme

  def initialize(uri)
    @scheme = uri.scheme
    super
  end

  def endpoint
    URI::Generic.build(scheme: scheme, host: host, port: port, path: path)
  rescue URI::Error => e
    raise SWD::Exception, e.message
  end

  prepend_features(::OpenIDConnect::Discovery::Provider::Config::Resource)
end
