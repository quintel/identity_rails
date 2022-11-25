# frozen_string_literal: true

module Identity
  module ApplicationHelper
    def show_auth_back_button?
      referrer = request.env['HTTP_REFERER']

      return true if referrer.blank?

      uri = URI.parse(referrer)

      (uri.host != request.host || uri.path != request.path) &&
        (!uri.path.start_with?('/auth/') && uri.host == request.host)
    end
  end
end
