# frozen_string_literal: true

# A controller which stubs some OAuth2 provider endpoints.
class ProviderController < ApplicationController
  def logout
    redirect_to params[:return_to], allow_other_host: true
  end
end
