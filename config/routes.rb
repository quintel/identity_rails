# frozen_string_literal: true

Identity::Engine.routes.draw do
  get 'identity',          to: 'auth#start'
  get 'identity/callback', to: 'auth#callback'
  get 'identity/failure',  to: 'auth#failure'
end
