# frozen_string_literal: true

RSpec.describe 'Sign in', type: :system do
  it 'signs a user in with a successful response' do
    mock_omniauth_user_sign_in

    visit '/'
    click_button 'Sign in'

    expect(page).to have_css('header', text: 'Signed in as hello@example.org')

    visit '/authenticated/user'
    expect(page).to have_content('User page')

    visit '/authenticated/admin'
    expect(page).to have_content('Page not found')
  end

  it 'remembers the location the user was trying to access' do
    mock_omniauth_user_sign_in

    visit '/authenticated/user'

    expect(page).to have_content('Page not found')
    expect(page).to have_content('If you were expecting something to be here, please sign in')

    click_button 'Sign in'

    expect(page).to have_content('User page')
  end

  it 'signs an admin in with a successful response' do
    mock_omniauth_admin_sign_in

    visit '/'
    click_button 'Sign in'

    expect(page).to have_css('header', text: 'Signed in as hello@example.org')

    visit '/authenticated/user'
    expect(page).to have_content('User page')

    visit '/authenticated/admin'
    expect(page).to have_content('Admin page')
  end

  it 'remembers the location the admin was trying to access' do
    mock_omniauth_admin_sign_in

    visit '/authenticated/admin'

    expect(page).to have_content('Page not found')
    expect(page).to have_content('If you were expecting something to be here, please sign in')

    click_button 'Sign in'

    expect(page).to have_content('Admin page')
  end
end
