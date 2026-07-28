# frozen_string_literal: true

RSpec.describe Identity::ApplicationHelper, type: :helper do
  describe '#identity_session_keeper_attributes' do
    it 'wires the session-keeper controller to the configured idp URL' do
      expect(helper.identity_session_keeper_attributes).to eq(
        controller: 'session-keeper',
        'session-keeper-idp-url-value': Identity.config.issuer,
        'session-keeper-exp-cookie-value': Identity.config.session_exp_cookie_name
      )
    end

    it 'tells the keeper which hint cookie this deployment writes' do
      allow(Identity.config).to receive(:session_exp_cookie_name).and_return('etm_session_exp_beta')

      expect(helper.identity_session_keeper_attributes)
        .to include('session-keeper-exp-cookie-value': 'etm_session_exp_beta')
    end
  end
end
