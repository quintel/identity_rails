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

      def load(oauth_client, hash)
        hash = serializer.loadable_hash(hash)

        if Identity.config.issuer != hash[:issuer]
          raise IssuerMismatch.new(Identity.config.issuer, hash[:issuer])
        end

        new(
          user: User.load(hash[:user]),
          access_token: OAuth2::AccessToken.from_hash(oauth_client, hash[:access_token])
        )
      end

      def load_fresh(oauth_client, hash)
        session = load(oauth_client, hash)
        session.expired? ? session.refresh : session
      end
    end

    def dump
      self.class.serializer.dump(self)
    end

    def expired?
      @access_token.expired?
    end

    # Creates a new session with a refreshed token. Also fetches a fresh copy of the user data in
    # case anything has changed.
    #
    # @return [Session] a new session with the refreshed token
    def refresh
      new_token = @access_token.refresh
      user_data = new_token.get('oauth/userinfo').parsed

      self.class.new(user: User.load(user_data), access_token: new_token)
    rescue OAuth2::Error => e
      raise(e.code == 'invalid_grant' ? InvalidGrant : Error, e.message)
    end
  end
end
