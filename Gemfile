source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use sqlite3 as the database for Active Record (development and test only)
gem "sqlite3", ">= 2.1", group: %i[ development test ]
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Git hook framework for pre-commit checks (secret scanning, etc.)
  gem "overcommit", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # RSpec-based testing harness (matches class hw2 convention)
  gem "rspec-rails", "~> 7.1"
  gem "factory_bot_rails", "~> 6.4"
  gem "faker", "~> 3.5"
end

group :test do
  # Concise validation/association matchers for RSpec
  gem "shoulda-matchers", "~> 6.4"
end

group :production do
  # PostgreSQL adapter used on Heroku
  gem "pg", "~> 1.5"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

gem "bcrypt", "~> 3.1"
gem "pagy", "~> 43.5"

# Google Calendar integration
gem "google-apis-calendar_v3", "~> 0.17"
gem "googleauth", "~> 1.11"

gem "dotenv-rails", "~> 3.2", groups: [:development, :test]

# OpenAI-compatible client for AI message generation via OpenRouter
gem "ruby-openai"
