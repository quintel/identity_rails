# frozen_string_literal: true

module Identity
  class Engine < ::Rails::Engine
    isolate_namespace Identity

    initializer 'identity.omniauth' do |app|
      app.middleware.use(::OmniAuth::Builder) do
        provider(
          Identity::OmniAuth::Strategy,
          Identity.config.client_id,
          Identity.config.client_secret,
          name: 'identity',
          scope: Identity.config.scope
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
