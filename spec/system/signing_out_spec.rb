# frozen_string_literal: true

RSpec.describe 'Sign out', type: :system do
  after { Identity.reset_config }

  it 'signs out and redirects to the root page' do
    Identity.config.client_id = 'abc123'
    Identity.config.issuer = Capybara.default_host

    sign_in
    expect(page).to have_content('Signed in as')

    click_button 'Sign out'
    expect(page).to have_content('Not signed in')
  end
end
