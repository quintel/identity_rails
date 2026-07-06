# frozen_string_literal: true

module Identity
  # Controller concern for resource servers (APIs that accept bearer JWTs). Owns the bearer-token
  # plumbing and verification; the including controller owns current_user and ability.
  #
  # Extract a token from the Authorization header (or an `access_token` param), verify it via
  # Identity::TokenDecoder, and memoise the decoded claims as #decoded_token.
  module ResourceServer
    extend ActiveSupport::Concern

    included do
      rescue_from Identity::TokenDecoder::DecodeError, with: :render_invalid_token
    end

    private

    # Returns the decoded/verified token claims, or nil if no token was provided.
    def decoded_token
      return @decoded_token if defined?(@decoded_token)

      @decoded_token = bearer_token && Identity::TokenDecoder.decode(bearer_token)
    end

    # The raw token from, in order: the Authorization header, the access_token param, or the shared
    # JWT session cookie (via Identity::ControllerHelpers#session_cookie_token, the single place the
    # cookie is read). Reading the cookie here is the unification seam: a browser request carrying
    # the domain cookie authenticates through the exact same path as an API bearer request.
    def bearer_token
      request.authorization.to_s[/\ABearer (.+)\z/, 1] ||
        params.permit(:access_token)[:access_token].presence ||
        session_cookie_token
    end

    def render_invalid_token
      render json: { errors: ['Invalid or expired token'] }, status: :unauthorized
    end
  end
end
