# frozen_string_literal: true

RSpec.describe Identity::ScenarioAccess do
  describe 'reading a claim' do
    subject(:access) do
      described_class.new(
        { 'latest' => { 'write' => [1, 3], 'read' => [2] }, '2025.01' => { 'write' => [4] } },
        tag: 'latest'
      )
    end

    it 'writes the Sessions granted write' do
      expect(access.writable).to contain_exactly(1, 3)
    end

    it 'reads the Sessions granted read or write' do
      expect(access.readable).to contain_exactly(1, 2, 3)
    end

    it 'answers per Session' do
      expect([access.writable?(1), access.writable?(2), access.readable?(2)]).to eq([true, false, true])
    end

    it 'gives nothing on a Session granted under another Version' do
      expect(access.readable?(4)).to be(false)
    end
  end

  describe 'the token contract with MyETM' do
    include ActiveSupport::Testing::TimeHelpers

    let(:contract) do
      JSON.parse(File.read(File.expand_path('../fixtures/token_contract.json', __dir__)))
    end

    let(:claim) { Identity::TokenDecoder.decode(contract['granted_token'])[described_class::CLAIM] }

    around do |example|
      travel_to(Time.at(contract['generated_at'])) { example.run }
    end

    before do
      Identity.config.issuer = contract['issuer']
      Identity.config.client_uri = contract['session_audience'].first
      allow(Identity::TokenDecoder).to receive(:jwk_set).and_return(contract['jwks'])
    end

    after { Identity.reset_config }

    it 'reads the grants MyETM mints for its own Version' do
      access = described_class.new(claim, tag: 'latest')

      expect([access.writable, access.readable]).to eq([[648_695], [648_695, 612_000]])
    end

    it 'keeps a Session ID granted on two Versions apart' do
      access = described_class.new(claim, tag: '2025.01')

      expect([access.writable, access.readable]).to eq([[612_000], [612_000]])
    end
  end

  describe 'a token signed by mock_identity_sign_in' do
    include Identity::Test::SystemHelpers

    it 'carries the extra claims it is given' do
      grant = { 'latest' => { 'write' => [5] } }
      token = mock_identity_sign_in(claims: { described_class::CLAIM => grant })

      claim = Identity::TokenDecoder.decode(token)[described_class::CLAIM]

      expect(described_class.new(claim, tag: 'latest').writable?(5)).to be(true)
    end
  end

  [
    ['no claim', nil],
    ['a claim that is not a hash', [1, 2]],
    ['no entry for the tag', { '2025.01' => { 'write' => [1] } }],
    ['the pre-Version flat shape', { 'write' => [1], 'read' => [2] }],
    ['levels that are not a hash', { 'latest' => [1] }],
    ['a level that is not a list', { 'latest' => { 'write' => 1 } }],
    ['ids that are not integers', { 'latest' => { 'write' => ['1'], 'read' => [nil, 2.0] } }]
  ].each do |description, claim|
    it "grants nothing for #{description}" do
      access = described_class.new(claim, tag: 'latest')

      expect([access.readable, access.writable]).to eq([[], []])
    end
  end
end
