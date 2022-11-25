# frozen_string_literal: true

Rails.application.routes.draw do
  mount Identity::Engine => '/auth'

  get '/authenticated/admin', to: 'authenticated#admin'
  get '/authenticated/user', to: 'authenticated#user'

  get '/logout', to: 'provider#logout'

  root to: 'home#root'
end
