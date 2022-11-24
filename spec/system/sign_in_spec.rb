# frozen_string_literal: true

RSpec.describe 'Sign in', type: :system do
  pending 'signs an admin in with a successful response' do
    mock_omniauth_user_sign_in

    visit '/auth/identity'

    expect(page).to have_content('Please sign in to your account')

    click_button 'Sign in'

    visit '/authenticated/user'
    expect(page).to have_content('User page')

    visit '/authenticated/admin'
    expect(page).to have_content('Not authorised')
  end

  it 'signs an admin in with a successful response' do
    mock_omniauth_admin_sign_in

    visit '/auth/identity'

    expect(page).to have_content('Please sign in to your account')

    click_button 'Sign in'

    visit '/authenticated/user'
    expect(page).to have_content('User page')

    visit '/authenticated/admin'
    expect(page).to have_content('Admin page')
  end
end
