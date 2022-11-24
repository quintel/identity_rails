# frozen_string_literal: true

RSpec.describe 'Sign in', type: :system do
  context 'when the user denied access' do
    it 'includes information about the failure' do
      OmniAuth.config.mock_auth[:identity] = :access_denied

      visit '/authenticated/user'
      click_button 'Sign in'

      expect(page).to have_css('h1', text: 'Signing in to your account failed')
      expect(page).to have_content('You denied the request')
    end
  end

  context 'when a generic error happens' do
    it 'includes information about the failure' do
      OmniAuth.config.mock_auth[:identity] = :unknown_error

      visit '/authenticated/user'
      click_button 'Sign in'

      expect(page).to have_css('h1', text: 'Signing in to your account failed')
      expect(page).not_to have_content('You denied the request')
    end
  end
end
