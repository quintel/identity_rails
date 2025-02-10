# frozen_string_literal: true

module Identity
  # Contains the access and refresh token, and expiry time.
  class AccessToken
    extend Dry::Initializer

    option :token,         Dry::Types['strict.string']
    option :refresh_token, Dry::Types['optional.strict.string']
    option :expires_at,    Dry::Types['optional.integer']
    option :created_at,    Dry::Types['strict.integer']

    # Unserialised
    option :uri,           Dry::Types['strict.string'], default: proc { Identity.config.issuer }
    option :name,          Dry::Types['strict.string'], default: proc { '' }
    option :refreshable,   Dry::Types['strict.bool'], default: proc { false }

    class << self
      def serializer
        @serializer ||= Serializer.new(
          token: ->(token) { token.token },
          refresh_token: ->(token) { token.refresh_token },
          expires_at: ->(token) { token.expires_at },
          created_at: ->(token) { token.created_at }
        )
      end

      # Public: Loads a token from a hash representation (typically from a Rails session).
      #
      # Raises a SchemaMismatch error if the schema version of the hash does not match the current
      # schema, or a KeyError if the hash is missing a required key.
      def load(hash, **kwargs)
        new(**serializer.loadable_hash(hash), **kwargs)
      rescue Dry::Types::ConstraintError => e
        raise Error, e.message
      end

      # Public: Creates a token from the credentials returned by OmniAuth.
      def from_omniauth_credentials(credentials, **kwargs)
        created_at = credentials['created_at'] || Time.now.to_i
        expires_at = credentials['expires_in'] ? created_at + credentials['expires_in'] : nil

        new(
          token: credentials['token'],
          refresh_token: credentials['refresh_token'],
          expires_at: expires_at,
          created_at: created_at,
          **kwargs
        )
      end
    end

    def http_client(**kwargs)
      kwargs[:uri] = @uri if @uri.present?
      Identity.http_client(access_token: token, **kwargs)
    end

    # Creates a new access token using the refresh token.
    def refresh
      raise(Error, 'A refresh token is not available') unless refresh_token

      # Use top-level http_client as we dont want to send the expired access token.
      response = Identity.http_client.post(Identity.discovery_config.token_endpoint, {
        refresh_token: refresh_token,
        grant_type: 'refresh_token',
        client_id: Identity.config.client_id,
        client_secret: Identity.config.client_secret
      })

      self.class.new(
        token: response.body['access_token'],
        refresh_token: response.body['refresh_token'],
        token_type: response.body['token_type'],
        expires_at: response.body['created_at'] + response.body['expires_in'],
        created_at: response.body['created_at']
      )
    rescue Faraday::Error => e
      raise Error.from_faraday(e)
    end

    # Returns if the access token has expired and needs to be refreshed.
    def expired?
      expires? && expires_at < Time.now.to_i
    end

    # Returns if the access token has expired, or will expire in the next 60 seconds.
    def expires_soon?
      return false unless refreshable
      return false unless expires?
      return false unless Identity.config.refresh_token_within

      Time.at(expires_at) < Time.now + Identity.config.refresh_token_within.seconds
    end

    # Returns if the token ever expires.
    def expires?
      !expires_at.nil?
    end

    def ==(other)
      other.is_a?(self.class) && other.token == token
    end

    # Public: Returns a hash representation of the token for serialization in the Rails session.
    def dump
      self.class.serializer.dump(self)
    end
  end
end
