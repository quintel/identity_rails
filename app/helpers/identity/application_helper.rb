# frozen_string_literal: true

module Identity
  module ApplicationHelper
    # Data attributes wiring the shared session-keeper Stimulus controller (identity/session_keeper).
    # Spread onto a persistent element (e.g. <body>) so a host app keeps the shared session alive
    # and recovers it without duplicating the idp URL or the controller name.
    def identity_session_keeper_attributes
      { controller: 'session-keeper', 'session-keeper-idp-url-value': Identity.config.issuer }
    end

    def show_auth_back_button?
      referrer = request.env['HTTP_REFERER']

      return true if referrer.blank?

      uri = URI.parse(referrer)

      (uri.host != request.host || uri.path != request.path) &&
        (!uri.path.start_with?('/auth/') && uri.host == request.host)
    end
  end
end
