# frozen_string_literal: true

RSpec.describe Identity::ConfigValidator do
  let(:result) { described_class.new.call(config) }

  let(:valid_config) do
    {
      issuer: 'https://issuer',
      client_id: 'client_id_123',
      client_secret: 'client_secret_123',
      client_uri: 'https://client',
      refresh_token_within: 60
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

  context 'with a missing client_id' do
    let(:config) { valid_config.except(:client_id) }

    it 'is a failure' do
      expect(result).to be_failure
    end

    it 'has an error on client_id' do
      expect(result.errors[:client_id]).to include('is missing')
    end
  end

  context 'with a missing client_secret' do
    let(:config) { valid_config.except(:client_secret) }

    it 'is a failure' do
      expect(result).to be_failure
    end

    it 'has an error on client_secret' do
      expect(result.errors[:client_secret]).to include('is missing')
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

    it 'raises an error when the refresh_token_within is nil' do
      config = valid_config.merge(refresh_token_within: nil)

      expect { described_class.validate!(config.to_h) }
        .to raise_error(Identity::InvalidConfig, /- refresh_token_within must be filled/)
    end

    it 'raises an error when the refresh_token_within a negative number' do
      config = valid_config.merge(refresh_token_within: -1)

      expect { described_class.validate!(config.to_h) }.to raise_error(
        Identity::InvalidConfig,
        /- refresh_token_within must be greater than or equal to 0/
      )
    end

    it 'raises no error when the refresh_token_within is a positive duration' do
      config = valid_config.merge(refresh_token_within: 1.minute)
      expect { described_class.validate!(config.to_h) }.not_to raise_error
    end

    it 'raises an error when the refresh_token_within is a negative duration' do
      config = valid_config.merge(refresh_token_within: -1.minute)

      expect { described_class.validate!(config.to_h) }.to raise_error(
        Identity::InvalidConfig,
        /- refresh_token_within must be greater than or equal to 0/
      )
    end
  end
end
