# frozen_string_literal: true

RSpec.describe Identity::ConfigValidator do
  let(:result) { described_class.new.call(config) }

  let(:valid_config) do
    {
      issuer: 'https://issuer',
      client_uri: 'https://client'
    }
  end

  context 'with a valid config' do
    let(:config) { valid_config }

    it 'is a success' do
      expect(result).to be_success
    end
  end

  context 'with a missing issuer' do
    let(:config) { valid_config.except(:issuer) }

    it 'is a failure' do
      expect(result).to be_failure
    end

    it 'has an error on issuer' do
      expect(result.errors[:issuer]).to include('is missing')
    end
  end

  context 'with a blank issuer' do
    let(:config) { valid_config.merge(issuer: '') }

    it 'has an error on issuer' do
      expect(result.errors[:issuer]).to include('must be filled')
    end
  end

  context 'when the issuer is not a valid URI' do
    let(:config) { valid_config.merge(issuer: '<>') }

    it 'has an error on issuer' do
      expect(result.errors[:issuer]).to include('must be a valid URI')
    end
  end

  context 'when the issuer is missing a protocol' do
    let(:config) { valid_config.merge(issuer: 'localhost') }

    it 'has an error on issuer' do
      expect(result.errors[:issuer]).to include('must have a http:// or https:// scheme')
    end
  end

  context 'when the issuer has a path' do
    let(:config) { valid_config.merge(issuer: 'http://localhost/no') }

    it 'has an error on issuer' do
      expect(result.errors[:issuer]).to include('must not have a path')
    end
  end

  context 'when the issuer has a query' do
    let(:config) { valid_config.merge(issuer: 'http://localhost?a=b') }

    it 'has an error on issuer' do
      expect(result.errors[:issuer]).to include('must not have a query')
    end
  end

  context 'when the issuer has a fragment' do
    let(:config) { valid_config.merge(issuer: 'http://localhost#a') }

    it 'has an error on issuer' do
      expect(result.errors[:issuer]).to include('must not have a fragment')
    end
  end

  # Sign-in is no longer an authorization-code flow, so this app registers no client. A deployment
  # whose settings still carry the old credentials stays valid: the contract ignores unknown keys.
  # TODO: remove this once the old client_id/client_secret are gone from all deployments.
  context 'with leftover client credentials' do
    let(:config) { valid_config.merge(client_id: 'abc', client_secret: 'def') }

    it 'is a success' do
      expect(result).to be_success
    end
  end

  context 'with a missing client_uri' do
    let(:config) { valid_config.except(:client_uri) }

    it 'is a failure' do
      expect(result).to be_failure
    end

    it 'has an error on client_uri' do
      expect(result.errors[:client_uri]).to include('is missing')
    end
  end

  describe '.validate!' do
    it 'raises no error when the config is valid' do
      expect { described_class.validate!(valid_config.to_h) }.not_to raise_error
    end

    it 'raises an error when the issuer is invalid' do
      config = valid_config.merge(issuer: '')

      expect { described_class.validate!(config.to_h) }
        .to raise_error(Identity::InvalidConfig, /- issuer must be filled/)
    end
  end
end
