require_relative 'lib/identity/version'

Gem::Specification.new do |spec|
  spec.name        = 'identity'
  spec.version     = Identity::VERSION
  spec.authors     = ['Anthony Williams']
  spec.email       = ['hi@antw.dev']
  spec.homepage    = 'https://github.com/quintel/identity_rails'
  spec.summary     = 'A Rails engine for interacting with the ETM Identity service.'
  spec.license     = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # spec.metadata['allowed_push_host'] = 'TODO: Set to 'http://mygemserver.com''

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  end

  spec.add_dependency 'dry-configurable', '>= 1.0'
  spec.add_dependency 'dry-initializer', '>= 3.1'
  spec.add_dependency 'dry-types', '~> 1.7'
  spec.add_dependency 'oauth2', '>= 2.0'
  spec.add_dependency 'omniauth', '>= 2.1'
  spec.add_dependency 'omniauth-oauth2', '>= 1.8'
  spec.add_dependency 'omniauth-rails_csrf_protection', '~> 1.0'
  spec.add_dependency 'rails', '>= 7.0.0'
end
