# frozen_string_literal: true

module Identity
  # Useful helpers for controllers and views.
  module ControllerHelpers
    extend ActiveSupport::Concern

    included do
      helper_method :current_user
      helper_method :sign_in_path
      helper_method :signed_in?
    end

    # Filters/Actions
    # ---------------

    # Used as a before_action to ensure that the user is signed in.
    #
    # If the user is signed in, the action will be executed as normal otherwise the "not authorized"
    # page will be rendered.
    def authenticate_user!
      unless signed_in?
        remember_return_to_path
        render('identity/auth/not_authorized', layout: 'identity/application', status: :not_found)
      end
    end

    # Used as a before_action to ensure that the user is signed in and has the admin role.
    #
    # If the user is authorized, the action will be executed as normal otherwise the "not
    # authorized" page will be rendered.
    def authenticate_admin!
      unless signed_in? && current_user.admin?
        remember_return_to_path
        render('identity/auth/not_authorized', layout: 'identity/application', status: :not_found)
      end
    end

    # Users
    # -----

    def signed_in?
      identity_session.present?
    end

    def current_user
      identity_session&.user
    end

    # Routes
    # ------

    def sign_in_path
      '/auth/identity'
    end

    private

    def identity_session
      return nil unless session[:identity].present?

      @identity_session ||= Identity::Session.load(Identity.oauth_client, session[:identity])
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
