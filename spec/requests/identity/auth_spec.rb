# frozen_string_literal: true

RSpec.describe 'Auth', type: :request do
  after { Identity.reset_config }

  def sign_in_cookie(token)
    cookies[Identity.config.session_cookie_name] = token
  end

  describe 'GET /auth/identity (start sign-in)' do
    context 'when not signed in' do
      it 'redirects to the provider’s sign-in page' do
        get '/auth/identity'

        expect(response).to have_http_status(:found)
        expect(response.location).to start_with("#{Identity.config.issuer}/identity/sign_in")
      end

      it 'carries the page the visitor wanted as an absolute return_to' do
        get '/authenticated/user'
        get '/auth/identity'

        query = Rack::Utils.parse_nested_query(URI.parse(response.location).query)

        expect(query['return_to']).to eq("#{Identity.config.client_uri}/authenticated/user")
      end

      it 'falls back to the app root when there is nothing to return to' do
        get '/auth/identity'

        query = Rack::Utils.parse_nested_query(URI.parse(response.location).query)

        expect(query['return_to']).to eq("#{Identity.config.client_uri}/")
      end
    end

    # A visitor can land here holding a valid cookie when the recovery probe slid a lapsed session
    # and reloaded. Sending them to the provider again would be a pointless round-trip.
    context 'when already signed in (session was silently recovered)' do
      before { sign_in_cookie(mock_identity_user_sign_in) }

      it 'forwards the visitor on instead of bouncing to the provider' do
        get '/auth/identity'

        expect(response).to redirect_to("#{Identity.config.client_uri}/")
      end
    end
  end

  describe 'POST /auth/sign_out' do
    context 'when not signed in' do
      it 'redirects to the root page' do
        post '/auth/sign_out'

        expect(response).to redirect_to('/')
      end
    end

    context 'when signed in' do
      before do
        Identity.config.client_id = 'abc123'
        sign_in_cookie(mock_identity_user_sign_in)
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
