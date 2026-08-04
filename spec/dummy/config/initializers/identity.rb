# frozen_string_literal: true

Identity.configure do |id_config|
  id_config.issuer = Capybara.default_host
  id_config.client_uri = Capybara.default_host
end
