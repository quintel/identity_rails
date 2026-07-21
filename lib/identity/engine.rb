# frozen_string_literal: true

module Identity
  class Engine < ::Rails::Engine
    # No OmniAuth provider is registered any more: apps do not run an authorization-code flow. The
    # provider's own login sets the shared session cookie on the parent domain, and each app
    # verifies that cookie locally (Identity::TokenDecoder), so there is no per-app OAuth session
    # left for a callback to establish.
    initializer 'identity.validate_config' do
      Identity::ConfigValidator.validate!(Identity.config.to_h) if Identity.config.validate_config
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
