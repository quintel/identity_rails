# frozen_string_literal: true

RSpec.describe 'Auth', type: :request do
  after { Identity.reset_config }

  describe 'POST /auth/logout' do
    context 'when not signed in' do
      it 'redirects to the root page' do
        post '/auth/logout'

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
        post '/auth/logout'

        expect(response).to have_http_status(:found)
        expect(response.location).to start_with("#{Identity.config.issuer}/logout")
      end

      it 'includes the client ID and redirect to in the redirect query string' do
        post '/auth/logout'

        uri = URI.parse(response.location)
        query = Rack::Utils.parse_nested_query(CGI.unescape(uri.query))

        expect(query).to eq(
          'client_id' => 'abc123',
          'return_to' => 'http://www.example.com/'
        )
      end
    end
  end
end
