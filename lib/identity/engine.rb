# frozen_string_literal: true

module Identity
  class Engine < ::Rails::Engine
    initializer 'identity.omniauth' do |app|
      if Identity.config.validate_config
        Identity::ConfigValidator.validate!(Identity.config.to_h)
      end

      # Monkeypatches OpenIDConnect to keep the HTTP scheme instead of forcing HTTPS for discovery
      # requests.
      #
      # See https://github.com/nov/openid_connect/issues/47#issuecomment-644799409
      Module.new do
        attr_reader :scheme

        def initialize(uri)
          @scheme = uri.scheme
          super
        end

        def endpoint
          URI::Generic.build(scheme: scheme, host: host, port: port, path: path)
        rescue URI::Error => e
          raise SWD::Exception, e.message
        end

        prepend_features(::OpenIDConnect::Discovery::Provider::Config::Resource)
      end

      app.middleware.use(::OmniAuth::Builder) do
        issuer = URI.parse(Identity.config.issuer)

        provider(
          :openid_connect,
          name: 'identity',
          discovery: true,
          issuer: Identity.config.issuer,
          response_code: :code,
          scope: Identity.config.scope,
          client_options: {
            port:         issuer.port,
            scheme:       issuer.scheme,
            host:         issuer.host,
            identifier:   Identity.config.client_id,
            secret:       Identity.config.client_secret,
            redirect_uri: "#{Identity.config.client_uri}/auth/identity/callback"
          }
        )
      end
    end

    # Include the ControllerHelpers in the application.
    initializer 'identity.controller_helpers' do
      ActiveSupport.on_load(:action_controller) do
        include Identity::ControllerHelpers

        require_relative '../../app/helpers/identity/application_helper'
        helper Identity::ApplicationHelper
      end
    end

    # Compile assets.
    initializer 'engine_name.assets.precompile' do |app|
      app.config.assets.precompile << 'identity_manifest.js'
    end

    config.generators do |g|
      g.test_framework(:rspec)
    end
  end
end
