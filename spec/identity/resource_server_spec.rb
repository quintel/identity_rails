# frozen_string_literal: true

RSpec.describe Identity::ResourceServer do
  let(:controller) do
    Class.new do
      def self.rescue_from(*); end
      def self.helper_method(*); end

      # ControllerHelpers provides session_cookie_token, the single place the cookie is read; every
      # real controller includes both concerns together (the engine mixes in ControllerHelpers
      # globally, ResourceServer is opt-in on top for API controllers).
      include Identity::ControllerHelpers
      include Identity::ResourceServer

      attr_writer :request, :params

      def request = @request
      def params = @params
      def cookies = {}
      def session = {}
    end.new
  end

  def request_double(authorization: nil, cookies: {})
    double('request', authorization: authorization, cookies: cookies)
  end

  describe '#bearer_token' do
    it 'reads the Authorization header first' do
      controller.request = request_double(
        authorization: 'Bearer header-token',
        cookies: { Identity.config.session_cookie_name => 'cookie-token' }
      )
      controller.params = ActionController::Parameters.new(access_token: 'param-token')

      expect(controller.send(:bearer_token)).to eq('header-token')
    end

    it 'falls back to the access_token param' do
      controller.request = request_double(cookies: {})
      controller.params = ActionController::Parameters.new(access_token: 'param-token')

      expect(controller.send(:bearer_token)).to eq('param-token')
    end

    it 'falls back to the JWT session cookie' do
      controller.request = request_double(
        cookies: { Identity.config.session_cookie_name => 'cookie-token' }
      )
      controller.params = ActionController::Parameters.new

      expect(controller.send(:bearer_token)).to eq('cookie-token')
    end

    it 'is nil when no token is present anywhere' do
      controller.request = request_double(cookies: {})
      controller.params = ActionController::Parameters.new

      expect(controller.send(:bearer_token)).to be_nil
    end
  end
end
