# frozen_string_literal: true

RSpec.describe Identity::ControllerHelpers do
  describe 'JWT session cookie identity' do
    let(:controller) do
      Class.new do
        def self.helper_method(*); end
        include Identity::ControllerHelpers

        attr_reader :request, :session

        define_method(:initialize) do
          @request = Struct.new(:cookies).new({})
          @session = {}
        end
      end.new
    end

    let(:claims) do
      { 'sub' => '42', 'user' => { 'email' => 'a@b.c', 'name' => 'Ada', 'admin' => true } }
    end

    context 'with a valid cookie' do
      before do
        controller.request.cookies[Identity.config.session_cookie_name] = 'raw.jwt'
        allow(Identity::TokenDecoder).to receive(:decode).and_return(claims)
      end

      it 'is signed in' do
        expect(controller.signed_in?).to be(true)
      end

      it 'builds the user from the claims' do
        user = controller.identity_user
        expect(user.id).to eq('42')
        expect(user.email).to eq('a@b.c')
        expect(user.name).to eq('Ada')
        expect(user.admin?).to be(true)
      end
    end

    context 'with a top-level roles claim' do
      before do
        controller.request.cookies[Identity.config.session_cookie_name] = 'raw.jwt'
        allow(Identity::TokenDecoder).to receive(:decode).and_return(
          claims.merge('roles' => %w[admin researcher])
        )
      end

      it 'uses the roles claim' do
        expect(controller.identity_user.roles).to include('researcher', 'admin')
      end
    end

    context 'with an invalid cookie' do
      before do
        controller.request.cookies[Identity.config.session_cookie_name] = 'bad'
        allow(Identity::TokenDecoder).to receive(:decode)
          .and_raise(Identity::TokenDecoder::DecodeError)
      end

      it 'is not signed in' do
        expect(controller.signed_in?).to be(false)
      end

      it 'has no identity user' do
        expect(controller.identity_user).to be_nil
      end
    end

    context 'with no cookie' do
      it 'is not signed in' do
        expect(controller.signed_in?).to be(false)
      end
    end
  end
end
