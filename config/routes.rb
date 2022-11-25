# frozen_string_literal: true

Identity::Engine.routes.draw do
  get 'identity',          to: 'auth#sign_in'
  get 'identity/callback', to: 'auth#callback'
  get 'failure',           to: 'auth#failure'
  post 'logout',           to: 'auth#sign_out'
end
