# Identity Rails

This is a Rails Engine for applications which need to authenticate and authorize users with the
ETM's [Identity](https://id.energytransitionmodel.com/users/sign_in) application. It provides
helpers for requiring that a user (or admin) be signed in to use controllers or actions, as well as
standard pages requesting the user sign in.

## Installation

Add the engine to the Rails application Gemfile:

```
gem 'identity_rails', github: 'quintel/identity_rails'
```

Create an initializer to set the client ID and secret (provided by the Identity app):

```ruby
# config/initializers/identity.rb

# Restart the server after making changes to these settings.
Identity.config.client_id = 'N8QmJxEELVK8gdjnLPTC6W6Etuf2cwcK'
Identity.config.client_secret = 'qTG4zH6VZT2KPVinHE5KhBZoySTVAKD5'
```

**Note that the mount path `/auth` is required, and must not be changed.**

## Usage

This engine provides two controller helpers which allow you to restrict who may use an action:

#### `authenticate_user!`

```ruby
before_action :authenticate_user!
```

Requires that the visitor be signed in to use the action. If not, they will be prompted to do so.

#### `authenticate_admin!`

```ruby
before_action :authenticate_admin!
```

Identical to `authenticate_user!` except that the signed-in user must also have the `admin` role.

#### `current_user`

Returns the current user, if signed in, or nil otherwise.

#### `signed_in?`

Returns whether the visitor is signed in.

#### `sign_in_path` / `sign_out_page`

Returns the paths for signing in or out. The sign in path responds to GET or POST requests: GET will
show a sign in prompt, while POST sends the user to the identity provider.

Signing out is only possible with a POST request. The user will be signed out of the application
_and_ the identity provider, and will finally be redirected back to the root of your application.

#### `identity_session`

Returns the current `Identity::Session` if the visitor is signed in. This gives access to the user
and a copy of the access token which can be used to send further requests to the identity provider.

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
