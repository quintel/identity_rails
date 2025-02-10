# frozen_string_literal: true

RSpec.describe Identity::TokenConfig do
  describe 'names' do
    context 'with basic unchanged config' do
      it 'contains one name' do
        expect(described_class.names.length).to eq(1)
      end
    end

    context 'with one sister config' do
      before do
        described_class.instance_variable_set(:@names, nil)

        allow(described_class).to receive(:sister_token_config).and_return([
          {
            name: 'etsister',
            uri: 'https://sister'
          }
        ])
      end

      it 'contains two names' do
        expect(described_class.names.length).to eq(2)
      end
    end
  end

  describe 'load_sister_tokens' do
    let(:token_attributes) do
      {
        'token' => '__access_token__',
        'refresh_token' => '__refresh_token__',
        'created_at' => Time.now.to_i,
        'expires_at' => (Time.now + 3600).to_i
      }
    end

    let(:token_hash) do
      {
        'etsister' => token_attributes,
        'etbrother' => token_attributes
      }
    end

    before do
      described_class.instance_variable_set(:@names, nil)

      allow(described_class).to receive(:sister_token_config).and_return([
        {
          name: 'etsister',
          uri: 'https://sister'
        },
        {
          name: 'etbrother',
          uri: 'https://brother'
        }
      ])
    end

    context 'with two sister tokens that were registrered in the config' do
      it 'loads both tokens' do
        expect(described_class.load_sister_tokens(token_hash).length).to eq(2)
      end

      it 'sets the correct name' do
        expect(described_class.load_sister_tokens(token_hash).first.name).to eq('etsister')
      end

      it 'sets the uri' do
        expect(described_class.load_sister_tokens(token_hash).first.uri).not_to be_nil
      end

      it 'makes them not refreshable' do
        expect(described_class.load_sister_tokens(token_hash).first.refreshable).to be_falsey
      end
    end

    context 'with two sister tokens but only one was registrered in the config' do
      before do
        described_class.instance_variable_set(:@names, nil)
        allow(described_class).to receive(:sister_token_config).and_return([
          {
            name: 'etsister',
            uri: 'https://sister'
          }
        ])
      end

      it 'loads one token' do
        expect(described_class.load_sister_tokens(token_hash).length).to eq(1)
      end

      it 'sets the correct name' do
        expect(described_class.load_sister_tokens(token_hash).first.name).to eq('etsister')
      end

      it 'sets the uri' do
        expect(described_class.load_sister_tokens(token_hash).first.uri).not_to be_nil
      end

      it 'makes them not refreshable' do
        expect(described_class.load_sister_tokens(token_hash).first.refreshable).to be_falsey
      end
    end
  end

  describe 'dump_tokens' do
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

    let(:sister_token) do
      instance_double(
        Identity::AccessToken,
        dump: { a: 1 },
        name: 'etsister'
      )
    end

    let(:session) do
      Identity::Session.new(user: user, access_token: access_token)
    end

    context 'with one access_token' do
      it 'returns the token under the correct key' do
        expect(described_class.dump_tokens(session)).to include(
          { Identity.config.client_name => { a: 1 } }
        )
      end
    end

    context 'with one valid sister access_token' do
      let(:session) do
        Identity::Session.new(
          user: user,
          access_token: access_token,
          sister_tokens: [sister_token]
        )
      end

      before do
        described_class.instance_variable_set(:@names, nil)
        allow(described_class).to receive(:sister_token_config).and_return([
          {
            name: 'etsister',
            uri: 'https://sister'
          }
        ])
      end

      it 'returns the access_token under the correct key' do
        expect(described_class.dump_tokens(session)).to include(
          { Identity.config.client_name => { a: 1 } }
        )
      end

      it 'returns the sister token under the correct key' do
        expect(described_class.dump_tokens(session)).to include(
          { 'etsister' => { a: 1 } }
        )
      end
    end

    context 'with one invalid sister access_token' do
      let(:session) do
        Identity::Session.new(
          user: user,
          access_token: access_token,
          sister_tokens: [sister_token]
        )
      end

      before do
        described_class.instance_variable_set(:@names, nil)
      end

      it 'returns only the access_token' do
        expect(described_class.dump_tokens(session)).to eq(
          { Identity.config.client_name => { a: 1 } }
        )
      end
    end

    context 'when there is a sister token in the config but not in the session' do
      before do
        described_class.instance_variable_set(:@names, nil)
        allow(described_class).to receive(:sister_token_config).and_return([
          {
            name: 'etsister',
            uri: 'https://sister'
          }
        ])
      end

      it 'returns only the access_token' do
        expect(described_class.dump_tokens(session)).to eq(
          { Identity.config.client_name => { a: 1 } }
        )
      end
    end
  end
end
