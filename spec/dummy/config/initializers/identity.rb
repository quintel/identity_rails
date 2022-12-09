# frozen_string_literal: true

Identity.configure do |id_config|
  id_config.issuer = Capybara.default_host
  id_config.client_id = SecureRandom.base58(16)
  id_config.client_secret = SecureRandom.base58(16)
  id_config.client_uri = Capybara.default_host
  id_config.scope = %w[public openid profile email]
end
