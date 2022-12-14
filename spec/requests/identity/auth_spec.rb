# frozen_string_literal: true

RSpec.describe 'Auth', type: :request do
  after { Identity.reset_config }

  describe 'POST /auth/logout' do
    context 'when not signed in' do
      it 'redirects to the root page' do
        post '/auth/sign_out'

        expect(response).to redirect_to('/')
      end
    end

    context 'when signed in' do
      before do
        Identity.config.client_id = 'abc123'

        mock_omniauth_user_sign_in
        get '/auth/identity/callback'
      end

      it 'redirects to the Identity app' do
        post '/auth/sign_out'

        expect(response).to have_http_status(:found)
        expect(response.location).to start_with("#{Identity.config.issuer}/identity/sign_out")
      end

      it 'includes the access token in the redirect query string' do
        post '/auth/sign_out'

        uri = URI.parse(response.location)
        query = Rack::Utils.parse_nested_query(CGI.unescape(uri.query))

        expect(query).to eq(
          'access_token' => OmniAuth.config.mock_auth[:identity]['credentials']['token']
        )
      end
    end
  end
end
