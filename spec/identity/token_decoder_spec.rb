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

  before { allow(described_class).to receive(:jwk_set).and_return(jwk_set) }

  describe '.decode' do
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
