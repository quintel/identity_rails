require 'dry-initializer'
require 'dry-types'
require 'oauth2'

require_relative 'identity/engine'
require_relative 'identity/errors'
require_relative 'identity/serializer'
require_relative 'identity/session'
require_relative 'identity/user'
require_relative 'identity/version'

# Helpers for interacting with the Identity authentication and authorization service.
module Identity
  extend Dry::Configurable

  setting :issuer, default: 'https://id.energytransitionmodel.com'
  setting :client_id
  setting :client_secret

  # Returns the configured OAuth2 client.
  #
  # @return [OAuth2::Client]
  def oauth_client
    @oauth_client ||= OAuth2::Client.new(
      config.client_id,
      config.client_secret,
      site: config.issuer
    )
  end
end
