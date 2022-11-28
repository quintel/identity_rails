# frozen_string_literal: true

module Identity
  class Engine < ::Rails::Engine
    isolate_namespace Identity

    initializer 'identity.omniauth' do |app|
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
        provider(
          :openid_connect,
          name: 'identity',
          discovery: true,
          issuer: Identity.config.issuer,
          response_code: :code,
          scope: Identity.config.scope,
          client_options: Identity.client_options
        )
      end
    end

    # Include the ControllerHelpers in the application.
    initializer 'identity.controller_helpers' do
      ActiveSupport.on_load(:action_controller) do
        include Identity::ControllerHelpers
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
