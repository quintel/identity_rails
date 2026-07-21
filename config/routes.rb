# frozen_string_literal: true

Rails.application.routes.draw do
  get 'auth/identity', to: 'identity/auth#sign_in', as: :sign_in

  match 'auth/sign_out', via: %i[get post], to: 'identity/auth#sign_out', as: :sign_out
end
