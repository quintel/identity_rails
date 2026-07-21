# frozen_string_literal: true

# Signing in happens at the provider, which sets the shared session cookie on the parent domain.
# From this app's point of view a signed-in visitor is simply one arriving with a valid cookie, so
# that is what these specs set up.
RSpec.describe 'Sign in', type: :system do
  it 'recognises a user arriving with a valid session cookie' do
    identity_session_cookie(mock_identity_user_sign_in)

    visit '/'
    expect(page).to have_css('header', text: 'Signed in as hello@example.org')

    visit '/authenticated/user'
    expect(page).to have_content('User page')

    visit '/authenticated/admin'
    expect(page).to have_content('Page not found')
  end

  it 'recognises an admin arriving with a valid session cookie' do
    identity_session_cookie(mock_identity_admin_sign_in)

    visit '/'
    expect(page).to have_css('header', text: 'Signed in as hello@example.org')

    visit '/authenticated/user'
    expect(page).to have_content('User page')

    visit '/authenticated/admin'
    expect(page).to have_content('Admin page')
  end

  it 'shows a signed-out visitor a prompt to sign in' do
    mock_identity_user_sign_in

    visit '/authenticated/user'

    expect(page).to have_content('Page not found')
    expect(page).to have_content('If you were expecting something to be here, please sign in')
  end

  # The provider needs to be told where to send the visitor back to, since there is no OAuth
  # round-trip carrying that state any more.
  it 'points the sign-in link at the provider, carrying the page the visitor wanted' do
    mock_identity_user_sign_in

    visit '/authenticated/user'
    href = page.find_link(href: %r{identity/sign_in})[:href]

    expect(href).to start_with("#{Identity.config.issuer}/identity/sign_in")
    expect(CGI.unescape(href)).to include('/authenticated/user')
  end
end
