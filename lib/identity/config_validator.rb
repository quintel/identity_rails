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
      optional(:client_name).value(:string)
      optional(:refresh_token_within).filled(:integer).value(gteq?: 0)

      optional(:sisters).value(:array).each do
        hash do
          required(:name).filled(:string)
          required(:uri).filled(:string)
        end
      end
    end

    rule(:issuer) do
      ConfigValidator.valid_uri!(value, key)
    end

    rule(:sisters).each do |index:|
      ConfigValidator.valid_uri!(value[:uri], key([:sisters, :uri, index]))
    end

    def self.valid_uri!(value, key)
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
