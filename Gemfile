# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in redis-client-namespace.gemspec
gemspec

group :development, :test do
  gem "rake", "~> 13.0"
  gem "redis"
  gem "rspec", "~> 3.0"
  gem "rubocop", "~> 1.21"
  gem "sidekiq", "~> 7.0" # For integration testing
end

group :benchmark do
  gem "benchmark-ips", "~> 2.13"
  gem "redis-namespace", "~> 1.11"
end
