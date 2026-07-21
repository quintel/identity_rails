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
      # Vestigial: nothing exchanges an authorization code any more, so no client secret is used.
      # Kept optional so existing deployments' settings stay valid; drop it once every app's config
      # has been cleaned up.
      optional(:client_secret).maybe(:string)
      required(:client_uri).filled(:string)
      optional(:resource_uri).maybe(:string)
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

    rule(:resource_uri) do
      unless value.blank?
        uri = URI.parse(value)

        key.failure('must have a http:// or https:// scheme') if uri.scheme.nil?
      end
    rescue URI::InvalidURIError
      key.failure('must be a valid URI')
    end
  end
end
