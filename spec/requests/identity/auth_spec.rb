# frozen_string_literal: true

RSpec.describe 'Auth', type: :request do
  after { Identity.reset_config }

  describe 'GET /auth/failure' do
    context 'with a real OAuth error' do
      it 'renders the failure page' do
        get '/auth/failure', params: { error: 'server_error' }

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to be_empty
      end
    end
  end

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

      it 'builds an RP-initiated logout URL with the client id and no access token' do
        post '/auth/sign_out'

        uri = URI.parse(response.location)
        query = Rack::Utils.parse_nested_query(CGI.unescape(uri.query))

        expect(query).to eq(
          'client_id' => Identity.config.client_id,
          'post_logout_redirect_uri' => "#{Identity.config.client_uri}/"
        )
      end
    end
  end
end
