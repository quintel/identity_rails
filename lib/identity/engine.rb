module Identity
  class Engine < ::Rails::Engine
    isolate_namespace Identity

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
