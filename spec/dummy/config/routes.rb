# frozen_string_literal: true

Rails.application.routes.draw do
  get '/authenticated/admin', to: 'authenticated#admin'
  get '/authenticated/user', to: 'authenticated#user'

  get '/identity/sign_out', to: 'provider#logout'

  root to: 'home#root'
end
