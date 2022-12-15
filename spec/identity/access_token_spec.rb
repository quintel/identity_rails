# frozen_string_literal: true

RSpec.describe Identity::AccessToken do
  let(:token_attributes) do
    { token: 'abc', refresh_token: 'def', expires_at: 456, created_at: 123 }
  end

  describe '.load' do
    context 'when given a token, refresh, and expires_at' do
      let(:token) do
        described_class.load(**token_attributes)
      end

      it 'sets the token' do
        expect(token.token).to eq('abc')
      end

      it 'sets the refresh token' do
        expect(token.refresh_token).to eq('def')
      end

      it 'sets the created_at' do
        expect(token.created_at).to eq(123)
      end

      it 'sets the expires_at' do
        expect(token.expires_at).to eq(456)
      end
    end

    context 'when given refresh and expires_at of nil' do
      let(:token) do
        described_class.load(**token_attributes.merge(refresh_token: nil, expires_at: nil))
      end

      it 'sets the refresh token to be nil' do
        expect(token.refresh_token).to be_nil
      end

      it 'sets the expires_at to be nil' do
        expect(token.expires_at).to be_nil
      end
    end
  end

  context 'when the expiry is in the future' do
    let(:token) do
      described_class.new(**token_attributes.merge(expires_at: Time.now.to_i + 10))
    end

    it 'returns false' do
      expect(token).not_to be_expired
    end

    it 'expires' do
      expect(token.expires?).to be(true)
    end
  end

  context 'when the expiry is in the past' do
    let(:token) do
      described_class.new(**token_attributes.merge(expires_at: Time.now.to_i - 10))
    end

    it 'returns true' do
      expect(token).to be_expired
    end

    it 'expires' do
      expect(token.expires?).to be(true)
    end
  end

  context 'when no expiry is set' do
    let(:token) do
      described_class.new(**token_attributes.merge(expires_at: nil))
    end

    it 'is expired' do
      expect(token).not_to be_expired
    end

    it 'does not expire' do
      expect(token.expires?).to be(false)
    end
  end

  describe '.from_omniauth_credentials' do
    let(:token) do
      described_class.from_omniauth_credentials({
        'token' => '__access_token__',
        'refresh_token' => '__refresh_token__',
        'expires_at' => 123
      })
    end

    it 'sets the token' do
      expect(token.token).to eq('__access_token__')
    end

    it 'sets the refresh_token' do
      expect(token.refresh_token).to eq('__refresh_token__')
    end

    it 'sets the expires_at' do
      expect(token.expires_at).to eq(123)
    end

    it 'sets the created_at' do
      expect(token.created_at).to be_within(2).of(Time.now.to_i)
    end
  end

  context 'when refreshing the token' do
    context 'when no refresh token is set' do
      let(:token) { described_class.new(**token_attributes.merge(refresh_token: nil)) }

      it 'raises an error' do
        expect { token.refresh }.to raise_error(Identity::Error, 'A refresh token is not available')
      end
    end

    context 'when a token is set' do
      let(:token) { described_class.new(**token_attributes) }
      let(:now)   { Time.now.to_i }

      before do
        conn = Faraday.new do |builder|
          builder.request(:json)
          builder.response(:json)

          builder.adapter(:test) do |stub|
            stub.post('oauth/token') do |_env|
              [
                200,
                { 'Content-Type': 'application/json; charset=utf-8' },
                {
                  'access_token' => 'hij',
                  'token_type' => 'Bearer',
                  'expires_in' => 7200,
                  'refresh_token' => 'klm',
                  'scope' => 'openid profile email scenarios:read',
                  'created_at' => now,
                  'id_token' => ''
                }.to_json
              ]
            end
          end
        end

        allow(Identity).to receive(:http_client).with(access_token: token.token).and_return(conn)
      end

      it 'returns an access token' do
        expect(token.refresh).to be_a(described_class)
      end

      it 'does not return the same object' do
        expect(token.refresh.__id__).not_to be(token.__id__)
      end

      it 'sets the new token' do
        expect(token.refresh.token).to eq('hij')
      end

      it 'sets the refresh token' do
        expect(token.refresh.refresh_token).to eq('klm')
      end

      it 'sets the expires_at' do
        expect(token.refresh.expires_at).to eq(now + 7200)
      end
    end

    context 'when the refresh endpoint returns a client error' do
      let(:token) { described_class.new(**token_attributes) }

      before do
        response = instance_double(Faraday::Response)
        allow(response).to receive(:[]).with(:body).and_return(
          {
            'error' => 'invalid_grant',
            'error_description' =>
              'The provided authorization grant is invalid, expired, revoked, does not ' \
              'match the redirection URI used in the authorization request, or was issued ' \
              'to another client.'
          }
        )

        conn = Faraday.new do |builder|
          builder.request(:json)
          builder.response(:json)

          builder.adapter(:test) do |stub|
            stub.post('oauth/token') do |_env|
              raise Faraday::BadRequestError.new(nil, response)
            end
          end
        end

        allow(Identity).to receive(:http_client).with(access_token: token.token).and_return(conn)
      end

      it 'raises an error' do
        expect { token.refresh }.to raise_error(
          Identity::Error,
          /Failed to refresh token: The provided authorization grant is invalid/
        )
      end
    end

    context 'when the refresh endpoint returns a server error' do
      let(:token) { described_class.new(**token_attributes) }

      before do
        conn = Faraday.new do |builder|
          builder.request(:json)
          builder.response(:json)

          builder.adapter(:test) do |stub|
            stub.post('oauth/token') do |_env|
              raise Faraday::Error, 'some message'
            end
          end
        end

        allow(Identity).to receive(:http_client).with(access_token: token.token).and_return(conn)
      end

      it 'raises an error' do
        expect { token.refresh }.to raise_error(Identity::Error, /some message/)
      end
    end
  end
end
