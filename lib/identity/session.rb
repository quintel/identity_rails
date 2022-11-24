# frozen_string_literal: true

module Identity
  # Contains the current user and access token.
  class Session
    extend Dry::Initializer

    option :user
    option :access_token

    class << self
      def serializer
        @serializer ||= Serializer.new(
          access_token: ->(session) { session.access_token.to_hash },
          user: ->(session) { session.user.dump },
          issuer: ->(*) { Identity.config.issuer }
        )
      end

      def from_omniauth(token, hash)
        new(
          user: User.from_omniauth_hash(hash),
          access_token: token
        )
      end

      def load(oath_client, hash)
        hash = serializer.loadable_hash(hash)

        if Identity.config.issuer != hash[:issuer]
          raise IssuerMismatch.new(Identity.config.issuer, hash[:issuer])
        end

        new(
          user: User.load(hash[:user]),
          access_token: OAuth2::AccessToken.from_hash(oath_client, hash[:access_token])
        )
      end
    end

    def dump
      self.class.serializer.dump(self)
    end

    def expired?
      @token.expired?
    end

    def can_refresh?
      @token.refresh_token.present?
    end

    # Refreshes the token. Raises an OAuth2::Error if the refresh request fails.
    def refresh
      @token = @token.refresh
    end
  end
end
