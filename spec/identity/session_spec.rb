# frozen_string_literal: true

RSpec.describe Identity::Session do
  describe '.from_omniauth' do
    let(:session) do
      described_class.from_omniauth(
        {
          'token' => '__access_token__',
          'refresh_token' => '__refresh_token__',
          'expires_at' => (Time.now + 3600).to_i
        },
        {
          'sub' => '123',
          'email' => 'hello@example.org',
          'name' => 'John Doe',
          'roles' => %w[admin]
        }
      )
    end

    it 'sets the user' do
      expect(session.user.dump).to eq(
        id: '123',
        email: 'hello@example.org',
        name: 'John Doe',
        roles: %w[admin]
      )
    end

    it 'sets the access token' do
      expect(session.access_token.token).to eq('__access_token__')
    end
  end

  describe '.load' do
    let(:user_attributes) do
      {
        'id' => '123',
        'roles' => %w[admin],
        'email' => 'hello@example.org',
        'name' => 'John Doe'
      }
    end

    let(:token_attributes) do
      {
        'token' => '__access_token__',
        'refresh_token' => '__refresh_token__',
        'created_at' => Time.now.to_i,
        'expires_at' => (Time.now + 3600).to_i
      }
    end

    context 'with valid attributes' do
      let(:session) do
        described_class.load(
          user: user_attributes,
          access_tokens: { Identity.config.client_name => token_attributes },
          issuer: Identity.config.issuer
        )
      end

      it 'sets the user' do
        expect(session.user.dump.transform_keys(&:to_s)).to eq(user_attributes)
      end

      it 'sets the token' do
        expect(session.access_token.dump.transform_keys(&:to_s)).to eq(token_attributes)
      end
    end

    context 'with a missing user' do
      it 'raises an error'  do
        expect do
          described_class.load(
            access_tokens: { Identity.config.client_name => token_attributes },
            issuer: Identity.config.issuer
          )
        end
          .to raise_error(
            Identity::SchemaMismatch,
            /expected {access_tokens, issuer, user}, got {access_tokens, issuer}/
          )
      end
    end

    context 'with a missing token' do
      it 'raises an error'  do
        expect do
          described_class.load(user: user_attributes, issuer: Identity.config.issuer)
        end
          .to raise_error(
            Identity::SchemaMismatch,
            /expected {access_tokens, issuer, user}, got {issuer, user}/
          )
      end
    end

    context 'with a missing issuer' do
      it 'raises an error'  do
        expect do
          described_class.load(
            user: user_attributes,
            access_tokens: { Identity.config.client_name => token_attributes }
          )
        end
          .to raise_error(
            Identity::SchemaMismatch,
            /expected {access_tokens, issuer, user}, got {access_tokens, user}/
          )
      end
    end

    context 'with an incorrect issuer' do
      it 'raises an error' do
        expect do
          described_class.load(
            user: user_attributes,
            access_tokens: { Identity.config.client_name => token_attributes },
            issuer: 'nope'
          )
        end
          .to raise_error(
            Identity::IssuerMismatch,
            /expected #{Identity.config.issuer.inspect}, got "nope"/
          )
      end
    end
  end

  # ------------------------------------------------------------------------------------------------

  describe '.load_fresh' do
    let(:user_attributes) do
      {
        'id' => '123',
        'roles' => %w[admin],
        'email' => 'hello@example.org',
        'name' => 'John Doe'
      }
    end

    let(:token_attributes) do
      { Identity.config.client_name => {
        'token' => '__access_token__',
        'refresh_token' => '__refresh_token__',
        'created_at' => Time.now.to_i,
        'expires_at' => expires_at.to_i
      }}
    end

    let(:result) do
      described_class.load_fresh(
        user: user_attributes,
        access_tokens: token_attributes,
        issuer: Identity.config.issuer
      )
    end

    let(:session) do
      result.first
    end

    context 'when the access token is valid' do
      let(:expires_at) { Time.now + 3600 }

      it 'returns a session as the first value' do
        expect(session).to be_a(described_class)
      end

      it 'returns that the session was not refreshed' do
        expect(result.last).to be(false)
      end

      it 'sets the access token' do
        expect(session.access_token.token).to eq('__access_token__')
      end

      it 'sets the user' do
        expect(session.user.email).to eq('hello@example.org')
      end
    end

    context 'when the access token is expired' do
      let(:expires_at) { Time.now - 1 }

      before do
        conn = HTTPClientHelpers.fake_client do |stub|
          stub.post('oauth/token') do |_env|
            [
              200,
              { 'Content-Type': 'application/json; charset=utf-8' },
              {
                'access_token' => '__refreshed_access_token__',
                'token_type' => 'Bearer',
                'expires_in' => 7200,
                'refresh_token' => '__refreshed_refresh_token__',
                'scope' => 'openid profile email scenarios:read',
                'created_at' => Time.now.to_i,
                'id_token' => ''
              }.to_json
            ]
          end

          stub.get('oauth/userinfo') do |_env|
            [
              200,
              { 'Content-Type': 'application/json; charset=utf-8' },
              {
                'sub' => user_attributes['id'],
                'email' => 'new@example.org',
                'roles' => user_attributes['roles'],
                'name' => user_attributes['name']
              }.to_json
            ]
          end
        end

        allow(Identity).to receive(:http_client).and_return(conn)
      end

      it 'returns a new session as the first value' do
        expect(session).to be_a(described_class)
      end

      it 'returns that the session was refreshed' do
        expect(result.last).to be(true)
      end

      it 'refreshes the access token' do
        expect(session.access_token.token).to eq('__refreshed_access_token__')
      end

      it 'refreshes the user data' do
        expect(session.user.email).to eq('new@example.org')
      end
    end
  end

  # ------------------------------------------------------------------------------------------------

  describe '#dump' do
    let(:user) do
      Identity::User.new(
        id: '123',
        email: 'hello@example.org',
        roles: %w[user],
        name: 'John Doe'
      )
    end

    let(:access_token) do
      instance_double(
        Identity::AccessToken,
        dump: { a: 1 },
        name: Identity.config.client_name
      )
    end

    let(:session) do
      described_class.new(user: user, access_token: access_token)
    end

    it 'dumps the access token' do
      expect(session.dump[:access_tokens]).to eq(Identity.config.client_name => { a: 1 })
    end

    it 'dumps the user' do
      expect(session.dump[:user]).to eq(user.dump)
    end

    it 'dumps the issuer' do
      expect(session.dump[:issuer]).to eq(Identity.config.issuer)
    end
  end
end
