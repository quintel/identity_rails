# frozen_string_literal: true

module Identity
  class Error < RuntimeError; end

  # Raised when refreshing a token fails due to the grant being revoked.
  class InvalidGrant < Error; end

  # Raised when loading user data from the session fails because the schema version of the user
  # data does not match the current schema version.
  class SchemaMismatch < Error
    def initialize(expected, actual)
      expected = expected.to_a.sort.join(', ')
      actual = actual.to_a.sort.join(', ')
      super("Schema version mismatch: expected {#{expected}}, got {#{actual}}")
    end
  end

  # Raised when deserializing a session fails due to the configured issuer not matching the
  # one used to serialize the session.
  class IssuerMismatch < Error
    def initialize(expected, actual)
      super("Issuer mismatch: expected #{expected.inspect}, got #{actual.inspect}")
    end
  end

  # Raises when trying to initialize Identity with an invalid or incomplete configuration.
  class InvalidConfig < Error
    def initialize(errors)
      messages = errors.map { |error| "- #{error.path.join('.')} #{error.text}" }.join("\n")
      super("Invalid or incomplete Identity configuration:\n\n#{messages}")
    end
  end
end
