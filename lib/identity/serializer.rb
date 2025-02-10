# frozen_string_literal: true

module Identity
  # Serializes sessions and users, enforcing the schema.
  class Serializer
    def initialize(**schema)
      @schema = schema
      @keys = Set.new(schema.keys.map(&:to_sym))
    end

    # Given a hash, return a hash that only contains the keys that are used by this serializer.
    #
    # Raises an error if the schema version is not the same as the current schema version.
    def loadable_hash(hash)
      hash = hash.transform_keys(&:to_sym)
      given_keys = Set.new(hash.keys)

      raise SchemaMismatch.new(@keys, given_keys) if @keys != given_keys

      hash.slice(*@schema.keys)
    end

    # Given an object, return a hash that serializes the object with the schema version.
    def dump(object)
      @schema.transform_values { |mapping| mapping.call(object) }
    end
  end
end
