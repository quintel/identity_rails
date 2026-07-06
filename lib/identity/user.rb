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
      # Public: Creates a user from the verified claims of the shared JWT session cookie. Roles
      # travel as a top-level claim when present; otherwise fall back to the boolean admin flag
      # carried in the `user` claim.
      def from_jwt_claims(claims)
        user = claims['user'] || {}

        new(
          id: claims['sub'],
          roles: claims['roles'] || (user['admin'] ? ['admin'] : []),
          email: user['email'],
          name: user['name']
        )
      rescue Dry::Types::ConstraintError => e
        raise Error, e.message
      end
    end

    def admin?
      roles.include?('admin')
    end

    # Public: Returns if the user is equal to the other object. This is the case if the other object
    # is also a user with the same ID.
    def ==(other)
      other.is_a?(self.class) && other.id == id
    end
  end
end
