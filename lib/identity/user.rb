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
      # Public: Creates a user from the verified claims of the shared JWT session cookie.
      #
      # Roles are reconstructed from the boolean `user.admin` flag, which is the only authorisation
      # data a token carries. There is no top-level `roles` claim to read: the provider has no role
      # system beyond admin — MyETM's own User#roles is itself derived, as `admin? ? %w[user admin]
      # : %w[user]` — so the same derivation is repeated here and a token stays that much smaller.
      # `roles` in the token's `scopes` is an OAuth scope of the same name, not a claim.
      def from_jwt_claims(claims)
        user = claims['user'] || {}

        new(
          id: claims['sub'],
          roles: user['admin'] ? %w[user admin] : %w[user],
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
