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

    config.generators do |g|
      g.test_framework(:rspec)
    end
  end
end
