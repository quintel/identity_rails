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
    end

    IDENTITY_SESSION_KEY = 'identity.session'

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
      identity_session.present?
    end

    def identity_user
      identity_session&.user
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

    private

    def identity_session
      return nil unless identity_session_attributes.present?
      return @identity_session if @identity_session

      id_session, refreshed = Identity::Session.load_fresh(identity_session_attributes)
      session[IDENTITY_SESSION_KEY] = id_session.dump if refreshed

      @identity_session = id_session
    rescue StandardError => e
      Rails.logger.error(e.message)
      Sentry.capture_exception(e) if defined?(Sentry)

      reset_session

      # A schema mismatch may occur if we change how we serialize data, and invalid grants can occur
      # if the user revokes the application's access to their account. Both are recoverable by
      # signing the user out.
      raise e unless e.is_a?(Identity::SchemaMismatch) || e.is_a?(Identity::InvalidGrant)
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

    # Returns the attributes stored in the session for authentication.
    def identity_session_attributes
      session[IDENTITY_SESSION_KEY]
    end
  end
end
