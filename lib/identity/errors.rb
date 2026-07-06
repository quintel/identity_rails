# frozen_string_literal: true

module Identity
  # General class for all errors in Identity.
  class Error < RuntimeError; end

  # Raises when trying to initialize Identity with an invalid or incomplete configuration.
  class InvalidConfig < Error
    def initialize(errors)
      messages = errors.map { |error| "- #{error.path.join('.')} #{error.text}" }.join("\n")
      super("Invalid or incomplete Identity configuration:\n\n#{messages}")
    end
  end
end
