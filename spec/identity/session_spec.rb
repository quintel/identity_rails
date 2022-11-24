# frozen_string_literal: true

RSpec.describe Identity::Session do
  let(:oauth_client) { instance_double(OAuth2::Client) }

  describe '.from_omniauth' do
    let(:token) { instance_double(OAuth2::AccessToken) }

    let(:session) do
      described_class.from_omniauth(
        token,
        {
          'uid' => '123',
          'info' => {
            'email' => 'hello@example.org',
            'name' => 'John Doe',
            'roles' => %w[admin]
          }
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
      expect(session.access_token).to eq(token)
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
        'token_type' => 'Bearer',
        'scope' => 'public',
        'access_token' => '__access_token__',
        'refresh_token' => '__refresh_token__',
        'created_at' => Time.now.to_i,
        'expires_at' => (Time.now + 3600).to_i
      }
    end

    context 'with valid attributes' do
      let(:session) do
        described_class.load(
          oauth_client,
          user: user_attributes,
          access_token: token_attributes,
          issuer: Identity.config.issuer
        )
      end

      it 'sets the user' do
        expect(session.user.dump.transform_keys(&:to_s)).to eq(user_attributes)
      end

      it 'sets the token' do
        expect(session.access_token.to_hash.transform_keys(&:to_s)).to eq(token_attributes)
      end
    end

    context 'with a missing user' do
      it 'raises an error'  do
        expect do
          described_class.load(
            oauth_client,
            access_token: token_attributes,
            issuer: Identity.config.issuer
          )
        end
          .to raise_error(
            Identity::SchemaMismatch,
            /expected {access_token, issuer, user}, got {access_token, issuer}/
          )
      end
    end

    context 'with a missing token' do
      it 'raises an error'  do
        expect do
          described_class.load(oauth_client, user: user_attributes, issuer: Identity.config.issuer)
        end
          .to raise_error(
            Identity::SchemaMismatch,
            /expected {access_token, issuer, user}, got {issuer, user}/
          )
      end
    end

    context 'with a missing issuer' do
      it 'raises an error'  do
        expect do
          described_class.load(oauth_client, user: user_attributes, access_token: token_attributes)
        end
          .to raise_error(
            Identity::SchemaMismatch,
            /expected {access_token, issuer, user}, got {access_token, user}/
          )
      end
    end

    context 'with an incorrect issuer' do
      it 'raises an error' do
        expect do
          described_class.load(
            oauth_client,
            user: user_attributes,
            access_token: token_attributes,
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
      instance_double(OAuth2::AccessToken, to_hash: { a: 1 })
    end

    let(:session) do
      described_class.new(user: user, access_token: access_token)
    end

    it 'dumps the access token' do
      expect(session.dump[:access_token]).to eq(a: 1)
    end

    it 'dumps the user' do
      expect(session.dump[:user]).to eq(user.dump)
    end

    it 'dumps the issuer' do
      expect(session.dump[:issuer]).to eq(Identity.config.issuer)
    end
  end
end
