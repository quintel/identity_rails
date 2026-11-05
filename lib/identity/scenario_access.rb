# frozen_string_literal: true

module Identity
  # The Sessions MyETM has granted on one Version, read from a token's scenario_access claim. The
  # claim maps each Version tag to its levels, e.g. { 'latest' => { 'write' => [1], 'read' => [2] } },
  # because each Version numbers its Sessions separately.
  class ScenarioAccess
    CLAIM = 'scenario_access'

    attr_reader :readable, :writable

    def initialize(claim, tag:)
      levels = claim.is_a?(Hash) ? claim[tag] : nil
      levels = {} unless levels.is_a?(Hash)

      @writable = ids_in(levels['write'])
      @readable = @writable | ids_in(levels['read'])
    end

    def readable?(id)
      readable.include?(id)
    end

    def writable?(id)
      writable.include?(id)
    end

    private

    def ids_in(list)
      list.is_a?(Array) ? list.grep(Integer) : []
    end
  end
end
