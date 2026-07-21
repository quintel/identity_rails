# frozen_string_literal: true

RSpec.describe 'Identity.discovery_config' do
  let(:document) do
    {
      'issuer' => 'http://identity.test',
      'jwks_uri' => 'http://identity.test/oauth/discovery/keys',
      'end_session_endpoint' => 'http://identity.test/identity/sign_out'
    }
  end

  let(:requests) { [] }

  let(:client) do
    HTTPClientHelpers.fake_client do |stub|
      stub.get('http://identity.test/.well-known/openid-configuration') do |env|
        requests << env.url.to_s
        [200, { 'Content-Type' => 'application/json' }, document.to_json]
      end
    end
  end

  before do
    # rails_helper stubs discovery_config for every other spec; this one is about the real thing.
    allow(Identity).to receive(:discovery_config).and_call_original
    allow(Identity).to receive(:http_client).and_return(client)

    Identity.config.issuer = 'http://identity.test'
    Identity.reset_discovery_config
  end

  after { Identity.reset_discovery_config }

  it 'fetches the well-known document from the issuer' do
    Identity.discovery_config

    expect(requests).to eq(['http://identity.test/.well-known/openid-configuration'])
  end

  it 'exposes the endpoints used by the gem' do
    expect(Identity.discovery_config).to include(
      jwks_uri: 'http://identity.test/oauth/discovery/keys',
      end_session_endpoint: 'http://identity.test/identity/sign_out'
    )
  end

  it 'reads keys with indifferent access' do
    expect(Identity.discovery_config['jwks_uri']).to eq(Identity.discovery_config[:jwks_uri])
  end

  it 'fetches the document only once' do
    3.times { Identity.discovery_config }

    expect(requests.length).to eq(1)
  end

  it 'preserves the issuer scheme rather than forcing HTTPS' do
    expect(Identity.discovery_config[:jwks_uri]).to start_with('http://')
  end

  context 'when the issuer has a trailing slash' do
    before do
      Identity.config.issuer = 'http://identity.test/'
      Identity.reset_discovery_config
    end

    it 'does not double up the separator' do
      Identity.discovery_config

      expect(requests).to eq(['http://identity.test/.well-known/openid-configuration'])
    end
  end
end
