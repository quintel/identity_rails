# frozen_string_literal: true

module Identity
  # Verifies that the Identity configuration is valid.
  class ConfigValidator < Dry::Validation::Contract
    def self.validate!(config)
      result = new.call(config)
      raise InvalidConfig, result.errors unless result.success?
    end

    params do
      required(:issuer).filled(:string)
      required(:client_id).filled(:string)
      required(:client_secret).filled(:string)
      required(:client_uri).filled(:string)
    end

    rule(:issuer) do
      uri = URI.parse(value)

      key.failure('must have a http:// or https:// scheme') if uri.scheme.nil?
      key.failure('must not have a path') unless uri.path.empty?
      key.failure('must not have a query') unless uri.query.nil?
      key.failure('must not have a fragment') unless uri.fragment.nil?
    rescue URI::InvalidURIError
      key.failure('must be a valid URI')
    end
  end
end
