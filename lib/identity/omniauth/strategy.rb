# frozen_string_literal: true

require 'omniauth'

module Identity
  module OmniAuth
    # Authenticates with the ETM Identity service.
    class Strategy < ::OmniAuth::Strategies::OAuth2
      option :name, :doorkeeper
      option :client_options, site: ::Identity.config.issuer, authorize_path: '/oauth/authorize'

      uid do
        raw_info['id']
      end

      info do
        { email: raw_info['email'], name: raw_info['name'], roles: raw_info['roles'] }
      end

      def raw_info
        @raw_info ||= access_token.get('/me.json').parsed
      end
    end
  end
end
