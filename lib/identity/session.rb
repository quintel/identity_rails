# frozen_string_literal: true

module Identity
  # Contains the current user and access token.
  class Session
    extend Dry::Initializer

    option :user
    option :access_token
    option :sister_tokens, optional: true, default: proc { [] }

    delegate :expired?, :expires_soon?, to: :access_token

    class << self
      def serializer
        @serializer ||= Serializer.new(
          access_tokens: ->(session) { TokenConfig.dump_tokens(session) },
          user: ->(session) { session.user.dump },
          issuer: ->(*) { Identity.config.issuer }
        )
      end

      def from_omniauth(credentials, hash, sister_tokens: [])
        new(
          user: User.from_omniauth_hash(hash),
          access_token: TokenConfig.load_from_omniauth_credentials(credentials),
          # TODO: sister token have to arrive here in some way
          sister_tokens: sister_tokens
        )
      end

      def load(hash)
        hash = serializer.loadable_hash(hash)

        if Identity.config.issuer != hash[:issuer]
          raise IssuerMismatch.new(Identity.config.issuer, hash[:issuer])
        end

        new(
          user: User.load(hash[:user]),
          access_token: TokenConfig.load_access_token(hash[:access_tokens]),
          sister_tokens: TokenConfig.load_sister_tokens(hash[:access_tokens])
        )
      end

      # Loads the session and refreshes the access token if it is about to expire.
      #
      # @return [Array<Session, Boolean>]
      #   a tuple containing the sessiona nd a boolean indicating whether the session was refreshed
      def load_fresh(hash)
        session = load(hash)
        session.expires_soon? ? [session.refresh, true] : [session, false]
      end
    end

    def sister_token_for(name)
      @sister_tokens.find { |token| token.name == name }
    end

    def tokens
      [@access_token] + @sister_tokens
    end

    def dump
      self.class.serializer.dump(self)
    end

    # Creates a new session with a refreshed token. Also fetches a fresh copy of the user data in
    # case anything has changed.
    #
    # @return [Session] a new session with the refreshed token
    def refresh
      new_token = @access_token.refresh

      user_data = Identity
        .http_client(access_token: new_token.token)
        .get(Identity.discovery_config.userinfo_endpoint)
        .body

      self.class.new(
        user: User.from_omniauth_hash(user_data),
        access_token: new_token,
        sister_access_token: @sister_access_token
      )
    end
  end
end
