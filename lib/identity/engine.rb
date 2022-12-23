# frozen_string_literal: true

module Identity
  class Engine < ::Rails::Engine
    initializer 'identity.omniauth' do |app|
      if Identity.config.validate_config
        Identity::ConfigValidator.validate!(Identity.config.to_h)
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
