# frozen_string_literal: true

RSpec.describe Identity::ApplicationHelper, type: :helper do
  describe '#identity_session_keeper_attributes' do
    it 'wires the session-keeper controller to the configured idp URL' do
      expect(helper.identity_session_keeper_attributes).to eq(
        controller: 'session-keeper',
        'session-keeper-idp-url-value': Identity.config.issuer
      )
    end
  end
end
