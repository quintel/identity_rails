# frozen_string_literal: true

module Identity
  # Useful helpers for controllers and views.
  module ControllerHelpers
    extend ActiveSupport::Concern

    included do
      helper_method :signed_in?
      helper_method :current_user
    end

    def signed_in?
      identity_session.present?
    end

    def current_user
      identity_session&.user
    end

    def identity_session
      @identity_session ||= session[:identity].present? && Identity::Session.load(
        Identity.oauth_client,
        session[:identity]
      )
    end
  end
end
