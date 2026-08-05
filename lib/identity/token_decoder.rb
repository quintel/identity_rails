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

      verify_audience!(payload['aud'])

      payload.with_indifferent_access
    rescue JWT::DecodeError => e
      raise DecodeError, e.message
    end

    # Audience is verified by #verify_audience! rather than by the `jwt` gem; see the note there.
    def decode_options
      {
        algorithms: ['RS256'],
        jwks: jwk_loader,
        verify_iss: true,
        iss: Identity.config.issuer,
        verify_aud: false,
        verify_expiration: true,
        required_claims: %w[sub exp]
      }
    end

    # `aud` is an array of the URIs a token is valid for: the shared session cookie targets several
    # in-scope apps at once. Membership is checked here instead of by JWT::Claims::Audience so that
    # tokens minted before the shared-cookie migration still verify — those carry `aud` as a single
    # space-delimited string ("https://a https://b"), which the gem compares by equality and would
    # reject, killing every personal access token issued before the cutover.
    #
    # TRANSITIONAL, paired with the legacy `kid` MyETM publishes at /oauth/discovery/keys. Both go
    # when the next major API break invalidates every pre-migration personal access token — a
    # forcing event, not a calendar date; a PAT can be minted for up to 365 days, so any removal
    # earlier than that must be coordinated with a user-visible change (API break notice, or a
    # signing-key rotation which kills every pre-migration token regardless of `kid`).
    #
    # Removing the `.split` below is the whole change — after it, a legacy space-joined `aud` no
    # longer matches anything.
    #
    # Note this is also a fix, not only a compatibility shim: the previous per-app decoders checked
    # `aud.include?(client_uri)` against a String, i.e. substring matching, so an `aud` of
    # "https://engine.example.com.evil" satisfied a client_uri of "https://engine.example.com".
    def verify_audience!(aud)
      audiences = Array(aud).flat_map { |entry| entry.to_s.split(' ') }
      return if audiences.include?(Identity.config.client_uri)

      raise JWT::DecodeError, 'Invalid audience'
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
    rescue Faraday::Error => e
      raise JWT::DecodeError, "Could not fetch the provider's JWKS: #{e.message}"
    end

    def jwks_client
      Faraday.new(Identity.discovery_config[:jwks_uri]) do |conn|
        conn.request(:json)
        conn.response(:json)
        conn.response(:raise_error)
      end
    end

    # Strips the ETM personal-access-token prefixes before verification.
    def strip_etm_prefix(token)
      token.sub(/^etm_(beta_)?/, '')
    end

    # Rails.cache is a NullStore by default in development, which would re-fetch the JWKS on every
    # token verification; fall back to a process-local store whenever caching is disabled.
    def jwk_cache
      @jwk_cache ||=
        if Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
          ActiveSupport::Cache::MemoryStore.new
        else
          Rails.cache
        end
    end
  end
end
