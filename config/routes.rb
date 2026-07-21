# frozen_string_literal: true

Rails.application.routes.draw do
  # Sign-in is a redirect to the provider, not an OAuth authorization-code round-trip: the
  # provider's login step sets the shared session cookie on the parent domain, so there is nothing
  # for a callback to do. See Identity::AuthController.
  get 'auth/identity', to: 'identity/auth#sign_in', as: :sign_in

  match 'auth/sign_out', via: %i[get post], to: 'identity/auth#sign_out', as: :sign_out
end
