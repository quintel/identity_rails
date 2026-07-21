# frozen_string_literal: true

module Identity
  # Useful helpers for controllers and views.
  module ControllerHelpers
    extend ActiveSupport::Concern

    included do
      helper_method :identity_user
      helper_method :signed_in?

      helper_method :sign_up_url
      helper_method :user_profile_url
      helper_method :identity_sign_in_url
    end

    # Rendering helpers
    # -----------------

    def render_identity_sign_in(status: :forbidden, **options)
      render('identity/auth/sign_in', layout: 'identity/application', status: status, **options)
    end

    def render_identity_not_authorized(status: :not_found, **options)
      render('identity/auth/not_authorized', layout: 'identity/application', status: status, **options)
    end

    # Filters/Actions
    # ---------------

    # Used as a before_action to ensure that the user is signed in.
    #
    # If the user is signed in, the action will be executed as normal otherwise the "not authorized"
    # page will be rendered.
    def authenticate_user!(show_as: :not_found)
      return if signed_in?

      remember_return_to_path
      show_as == :sign_in ? render_identity_sign_in : render_identity_not_authorized
    end

    # Used as a before_action to ensure that the user is signed in and has the admin role.
    #
    # If the user is authorized, the action will be executed as normal otherwise the "not
    # authorized" page will be rendered.
    def authenticate_admin!(show_as: :not_found)
      return if signed_in? && identity_user.admin?

      remember_return_to_path
      show_as == :sign_in ? render_identity_sign_in : render_identity_not_authorized
    end

    # Users
    # -----

    def signed_in?
      identity_token.present?
    end

    def identity_user
      return @identity_user if defined?(@identity_user)

      @identity_user = identity_token && Identity::User.from_jwt_claims(identity_token)
    end

    # Routes
    # ------

    def user_profile_url
      uri = URI.parse(Identity.config.issuer)
      uri.path = '/identity/profile'
      uri.query = { client_id: Identity.config.client_id }.to_query

      uri.to_s
    end

    def sign_up_url
      uri = URI.parse(Identity.config.issuer)
      uri.path = '/identity/sign_up'

      uri.to_s
    end

    # The provider's sign-in page, carrying the page to come back to afterwards.
    #
    # Signing in is a plain top-level navigation to the provider: it owns the form, and its login
    # step sets the shared session cookie on the parent domain, which is all this app needs. There
    # is no OAuth round-trip to bring the visitor back, so the destination travels as `return_to`
    # and the provider validates it against its registered applications before redirecting.
    def identity_sign_in_url(return_to: nil)
      uri = URI.parse(Identity.config.issuer)
      uri.path = '/identity/sign_in'
      uri.query = { return_to: return_to || request.original_url }.to_query

      uri.to_s
    end

    private

    # The verified claims of the JWT session cookie, or nil when it is absent or invalid. This is
    # the shared domain cookie that acts as the browser session: a missing or expired cookie simply
    # means "signed out", so the user re-authenticates (or the session is refreshed) rather than
    # seeing a 401 (contrast with Identity::ResourceServer, which raises for API requests).
    def identity_token
      return @identity_token if defined?(@identity_token)

      @identity_token = session_cookie_token && Identity::TokenDecoder.decode(session_cookie_token)
    rescue Identity::TokenDecoder::DecodeError
      @identity_token = nil
    end

    # The raw JWT from the shared session cookie, or nil. Uses request.cookies (not the `cookies`
    # helper) so the same extraction works from Identity::ResourceServer in API controllers too;
    # it's the single place either concern reads the cookie.
    def session_cookie_token
      request.cookies[Identity.config.session_cookie_name].presence
    end

    # Remembers the current path so that the user can be redirected back to it after signing in.
    def remember_return_to_path
      if request.format.html? && request.get? && !is_a?(Identity::ApplicationController)
        session[:return_to] = request.fullpath
      end
    end

    # Removes and returns the return_to path from the session, if set, otherwise returns the given
    # fallback path.
    def return_to_path(fallback)
      session.delete(:return_to) || fallback
    end
  end
end
