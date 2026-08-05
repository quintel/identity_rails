# frozen_string_literal: true

RSpec.describe Identity::TokenDecoder do
  let(:key) { OpenSSL::PKey::RSA.new(2048) }
  let(:jwk_set) { { 'keys' => [JWT::JWK.new(key.public_key, 'test_key').export] } }

  let(:claims) do
    {
      iss: Identity.config.issuer,
      aud: Identity.config.client_uri,
      sub: '123',
      exp: 1.hour.from_now.to_i,
      scopes: %w[public]
    }
  end

  def sign(payload, signing_key: key, kid: 'test_key')
    JWT.encode(payload, signing_key, 'RS256', kid: kid)
  end

  describe '.decode' do
    before { allow(described_class).to receive(:jwk_set).and_return(jwk_set) }

    it 'decodes and returns a valid token' do
      decoded = described_class.decode(sign(claims))

      expect(decoded['sub']).to eq('123')
      expect(decoded['aud']).to eq(Identity.config.client_uri)
    end

    it 'strips the etm_ prefix' do
      expect { described_class.decode("etm_#{sign(claims)}") }.not_to raise_error
    end

    it 'strips the etm_beta_ prefix' do
      expect { described_class.decode("etm_beta_#{sign(claims)}") }.not_to raise_error
    end

    it 'rejects a wrong issuer' do
      expect { described_class.decode(sign(claims.merge(iss: 'https://evil'))) }
        .to raise_error(Identity::TokenDecoder::DecodeError)
    end

    it 'rejects a wrong audience' do
      expect { described_class.decode(sign(claims.merge(aud: 'other_client'))) }
        .to raise_error(Identity::TokenDecoder::DecodeError)
    end

    it 'accepts an array audience that includes the client' do
      aud = ['https://other.example', Identity.config.client_uri]
      expect { described_class.decode(sign(claims.merge(aud: aud))) }.not_to raise_error
    end

    it 'rejects an array audience that excludes the client' do
      expect { described_class.decode(sign(claims.merge(aud: %w[https://a https://b]))) }
        .to raise_error(Identity::TokenDecoder::DecodeError)
    end

    # TRANSITIONAL — delete alongside the `.split` in TokenDecoder#verify_audience!.
    context 'with a legacy space-delimited audience string' do
      it 'accepts one that includes the client' do
        aud = "https://other.example #{Identity.config.client_uri}"
        expect { described_class.decode(sign(claims.merge(aud: aud))) }.not_to raise_error
      end

      it 'rejects one that excludes the client' do
        expect { described_class.decode(sign(claims.merge(aud: 'https://a https://b'))) }
          .to raise_error(Identity::TokenDecoder::DecodeError)
      end
    end

    # The per-app decoders this gem replaced compared with String#include?, so a lookalike host
    # that merely contained the client_uri as a substring was accepted.
    it 'rejects an audience that only contains the client uri as a substring' do
      expect { described_class.decode(sign(claims.merge(aud: "#{Identity.config.client_uri}.evil"))) }
        .to raise_error(Identity::TokenDecoder::DecodeError)
    end

    it 'rejects a missing subject' do
      expect { described_class.decode(sign(claims.merge(sub: nil))) }
        .to raise_error(Identity::TokenDecoder::DecodeError)
    end

    it 'rejects an expired token' do
      expect { described_class.decode(sign(claims.merge(exp: 1.hour.ago.to_i))) }
        .to raise_error(Identity::TokenDecoder::DecodeError)
    end

    it 'rejects a token signed by an unknown key' do
      expect { described_class.decode(sign(claims, signing_key: OpenSSL::PKey::RSA.new(2048))) }
        .to raise_error(Identity::TokenDecoder::DecodeError)
    end
  end

  # Unlike the rest of the file these exercise the real jwk_set, so they must not stub it.
  describe '.decode when the provider cannot be reached' do
    before { described_class.jwk_cache.delete(described_class::JWK_CACHE_KEY) }

    # Mirrors the middleware stack of the real jwks_client; raise_error is what turns a non-2xx
    # response into an exception.
    def jwks_client(status, body = '')
      Faraday.new do |conn|
        conn.response(:json)
        conn.response(:raise_error)
        conn.adapter(:test) do |stub|
          stub.get('/') { [status, { 'Content-Type' => 'application/json' }, body] }
        end
      end
    end

    it 'treats a JWKS endpoint error as an undecodable token' do
      allow(described_class).to receive(:jwks_client).and_return(jwks_client(500))

      expect { described_class.decode(sign(claims)) }
        .to raise_error(Identity::TokenDecoder::DecodeError)
    end

    it 'treats a JWKS timeout as an undecodable token' do
      client = instance_double(Faraday::Connection)
      allow(client).to receive(:get).and_raise(Faraday::TimeoutError)
      allow(described_class).to receive(:jwks_client).and_return(client)

      expect { described_class.decode(sign(claims)) }
        .to raise_error(Identity::TokenDecoder::DecodeError)
    end

    it 'treats a discovery document failure as an undecodable token' do
      allow(Identity).to receive(:discovery_config).and_raise(Faraday::ConnectionFailed, 'refused')

      expect { described_class.decode(sign(claims)) }
        .to raise_error(Identity::TokenDecoder::DecodeError)
    end

    # Guards the deliberate choice of Faraday::Error over StandardError: a misconfiguration or a
    # coding mistake must not be swallowed into a silent sign-out.
    it 'lets a non-Faraday error propagate' do
      allow(described_class).to receive(:jwks_client).and_raise(ArgumentError, 'no jwks_uri')

      expect { described_class.decode(sign(claims)) }.to raise_error(ArgumentError)
    end

    # Nothing is cached on failure, so verification recovers as soon as the provider does.
    it 'caches nothing, so the next attempt succeeds once the provider recovers' do
      allow(described_class).to receive(:jwks_client)
        .and_return(jwks_client(500), jwks_client(200, jwk_set.to_json))

      expect { described_class.decode(sign(claims)) }
        .to raise_error(Identity::TokenDecoder::DecodeError)
      expect { described_class.decode(sign(claims)) }.not_to raise_error
    end
  end

  describe '.decode key rotation' do
    it 'busts the cache and retries when the kid is not found' do
      stale = { 'keys' => [JWT::JWK.new(OpenSSL::PKey::RSA.new(2048).public_key, 'old').export] }

      allow(described_class).to receive(:jwk_set).and_return(stale, jwk_set)

      # First lookup misses (stale set); the jwt gem retries once with invalidate: true.
      expect { described_class.decode(sign(claims)) }.not_to raise_error
      expect(described_class).to have_received(:jwk_set).with(invalidate: true)
    end
  end
end
