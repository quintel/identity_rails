# Identity Rails

This is a Rails Engine for applications which need to authenticate and authorize users with the
ETM's [Identity](https://id.energytransitionmodel.com/users/sign_in) application. It provides
helpers for requiring that a user (or admin) be signed in to use controllers or actions, as well as
standard pages requesting the user sign in.

## How sign-in works

The browser session is a single JWT, held in a cookie (`etm_session` by default) scoped to the
parent domain shared by every ETM app. The provider (MyETM) mints and refreshes this cookie; every
other app only ever reads and verifies it — there is no local session state to keep in sync. The
"Sign in" link still routes the visitor through the provider's login page (so a fresh browser is
prompted to authenticate), but the cookie is what makes the visitor "signed in" here, both for
resource-server requests (`Identity::ResourceServer`, which also accepts the same cookie value as a
bearer token) and for a normal signed-in page load (`Identity::ControllerHelpers`).

## Installation

Add the engine to the Rails application Gemfile:

```
gem 'identity_rails', github: 'quintel/identity_rails'
```

Create an initializer naming the Identity app and this application's own base URL.

```ruby
# config/initializers/identity.rb

# Restart the server after making changes to these settings.
Identity.config.issuer = 'https://my.energytransitionmodel.com'
Identity.config.client_uri = 'https://my-app.energytransitionmodel.com'
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

#### `identity_user`

Returns the current `Identity::User`, if signed in, or nil otherwise.

#### `signed_in?`

Returns whether the visitor is signed in (i.e. whether the shared session cookie is present and
verifies).

#### `sign_in_path` / `sign_out_page`

Returns the paths for signing in or out. The sign in path responds to GET or POST requests: GET will
show a sign in prompt, while POST sends the user to the identity provider.

Signing out is only possible with a POST request. The user will be signed out of the application
_and_ the identity provider, and will finally be redirected back to the root of your application.

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).
