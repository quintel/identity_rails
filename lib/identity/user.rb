# frozen_string_literal: true

module Identity
  # Provides information about the signed-in user.
  class User
    extend Dry::Initializer

    option :id,    Dry::Types['coercible.string'].constrained(min_size: 1)
    option :roles, Dry::Types::Constructor.new(Set) { |v| Set.new(Array(v).map(&:to_s)) }
    option :email, Dry::Types['optional.strict.string']
    option :name,  Dry::Types['optional.strict.string']

    class << self
      def serializer
        @serializer ||= Serializer.new(
          id: ->(user) { user.id },
          roles: ->(user) { user.roles.to_a },
          email: ->(user) { user.email },
          name: ->(user) { user.name }
        )
      end

      # Public: Creates a user from an OmniAuth::AuthHash.
      def from_omniauth_hash(hash)
        new(
          id: hash['uid'],
          roles: hash['info']['roles'],
          email: hash['info']['email'],
          name: hash['info']['name']
        )
      end

      # Public: Loads a user from a hash representation (typically from a Rails session).
      #
      # Raises a SchemaMismatch error if the schema version of the hash does not match the current
      # schema, or a KeyError if the hash is missing a required key.
      def load(hash)
        new(**serializer.loadable_hash(hash))
      rescue Dry::Types::ConstraintError => e
        raise Error, e.message
      end
    end

    def admin?
      roles.include?('admin')
    end

    # Public: Returns a hash representation of the user for serialization in the Rails session.
    def dump
      self.class.serializer.dump(self)
    end
  end
end
