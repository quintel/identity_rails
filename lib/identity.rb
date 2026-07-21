# frozen_string_literal: true

require 'dry-initializer'
require 'dry-types'
require 'dry-validation'
require 'faraday'

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

  # Returns the provider's OpenID Connect discovery document, fetched once per process.
  #
  # Only two entries are used (jwks_uri, end_session_endpoint), so this is a plain GET of the
  # well-known document rather than a dependency on the openid_connect gem: that gem pulled in six
  # transitive dependencies — including json-jwt, which TokenDecoder was deliberately moved off —
  # and forced HTTPS on discovery, which needed a monkeypatch to undo for local development.
  #
  # @return [ActiveSupport::HashWithIndifferentAccess]
  def self.discovery_config
    @discovery_config ||= http_client
      .get("#{Identity.config.issuer.to_s.chomp('/')}/.well-known/openid-configuration")
      .body
      .with_indifferent_access
  end

  # Forgets the memoised discovery document. Mainly useful in tests, and after reconfiguring the
  # issuer at runtime.
  def self.reset_discovery_config
    @discovery_config = nil
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
