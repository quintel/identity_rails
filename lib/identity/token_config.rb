# frozen_string_literal: true

module Identity
  # Loads and verifies tokens according to the config
  class TokenConfig
    class << self
      def names
        @names ||=
          sister_token_config.map do |token|
            token[:name]
          end + [Identity.config.client_name]
      end

      def sister_token_config
        @sister_token_config ||= Identity.config.sisters.map { |t| t.transform_keys(&:to_sym) }
      end

      # Returns an array of token configs, of token names that not have been registered
      # in the session
      def unregistered_tokens_for(session)
        missing_names = TokenConfig.names - session.tokens.map(&:name)
        sister_token_config.select { |config| missing_names.includes?(config[:name]) }
      end

      # Takes a hash from the saved session and returns an array of
      # sister tokens for the session
      def load_sister_tokens(hash)
        sister_token_config.filter_map do |token_config|
          if hash.key?(token_config[:name])
            AccessToken.load(
              hash[token_config[:name]],
              **token_config
            )
          end
        end
      end

      # Loads the default access_token for communication with the issuer
      def load_access_token(hash)
        AccessToken.load(
          hash[Identity.config.client_name],
          name: Identity.config.client_name,
          refreshable: true
        )
      end

      # Loads the main access_token for the session from the credentials
      def load_from_omniauth_credentials(credentials)
        AccessToken.from_omniauth_credentials(
          credentials,
          name: Identity.config.client_name,
          refreshable: true
        )
      end

      # Returns a hash with all names to be used by the serialiser
      def dump_tokens(session)
        session.tokens.each_with_object({}) do |token, hash|
          hash[token.name] = token.dump if TokenConfig.names.include?(token.name)
        end
      end
    end
  end
end
