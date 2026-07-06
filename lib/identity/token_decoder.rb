# frozen_string_literal: true

require 'jwt'

module Identity
  # Resource-server JWT verification. Decodes and verifies bearer tokens issued by the Identity
  # provider, validating the signature against the provider's JWKS and the standard claims.
  #
  # This is the single implementation shared by all resource servers (ETEngine, ETModel); each app
  # previously kept its own near-identical copy.
  module TokenDecoder
    module_function

    DecodeError = Class.new(Identity::Error)

    JWK_CACHE_KEY = 'identity.jwk_set'

    # Decodes and verifies a JWT, returning the decoded claims with indifferent access (consumers
    # across ETEngine/ETModel read claims via both string and symbol keys).
    #
    # Raises DecodeError if the signature or any claim is invalid.
    def decode(raw)
      payload, = JWT.decode(strip_etm_prefix(raw), nil, true, decode_options)

      # required_claims only checks that the key exists, not that it's non-blank; a `sub: null`
      # claim would otherwise pass.
      raise JWT::DecodeError, 'Missing sub claim' if payload['sub'].blank?

      payload.with_indifferent_access
    rescue JWT::DecodeError => e
      raise DecodeError, e.message
    end

    # `aud` may be a single URI or a JSON array of URIs: the shared session cookie targets several
    # in-scope apps at once. JWT::Claims::Audience already checks membership (not equality) when
    # either side is an array, so no hand-rolled normalisation is needed here.
    def decode_options
      {
        algorithms: ['RS256'],
        jwks: jwk_loader,
        verify_iss: true,
        iss: Identity.config.issuer,
        verify_aud: true,
        aud: Identity.config.client_uri,
        verify_expiration: true,
        required_claims: %w[sub exp]
      }
    end

    # Resolves the signing key for a token by `kid`, fetching (and caching) the provider's JWKS.
    # The `jwt` gem retries once with `invalidate: true` when the kid isn't found in the cached set
    # (the provider may have rotated its keys), which covers key rotation with no hand-rolled retry
    # logic here.
    def jwk_loader
      ->(options) { jwk_set(invalidate: options[:invalidate]) }
    end

    # Fetches (and caches for 24h) the provider's full JWKS document. Using the whole set rather
    # than a single key keeps verification working across key rotation.
    def jwk_set(invalidate: false)
      jwk_cache.delete(JWK_CACHE_KEY) if invalidate

      jwk_cache.fetch(JWK_CACHE_KEY, expires_in: 24.hours) { jwks_client.get.body }
    end

    def jwks_client
      Faraday.new(Identity.discovery_config.jwks_uri) do |conn|
        conn.request(:json)
        conn.response(:json)
        conn.response(:raise_error)
      end
    end

    # Strips the ETM personal-access-token prefixes before verification.
    def strip_etm_prefix(token)
      token.sub(/^etm_(beta_)?/, '')
    end

    def jwk_cache
      @jwk_cache ||=
        if defined?(Rails) && Rails.env.development?
          ActiveSupport::Cache::MemoryStore.new
        else
          Rails.cache
        end
    end
  end
end
