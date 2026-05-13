require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Heroku terminates SSL at its router.
  config.assume_ssl = true
  config.force_ssl  = true
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Heroku dynos are single-process so an in-memory cache is fine for M0.
  # Override the Rails 8.1 solid_cache default, which expects a separate
  # :cache database that we don't provision on Heroku.
  config.cache_store = :memory_store

  # Run background jobs inline (solid_queue needs its own DB which we skip).
  # No jobs are queued in M0, but Rails still boots the adapter.
  config.active_job.queue_adapter = :async

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Allow Heroku *.herokuapp.com domains plus any custom host passed via env.
  config.hosts << /.*\.herokuapp\.com\z/
  config.hosts << ENV["APP_HOST"] if ENV["APP_HOST"].present?
  config.host_authorization = { exclude: ->(request) { request.path == "/up" } }

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address:              ENV["SMTP_HOST"],
    port:                 ENV["SMTP_PORT"].to_i,
    user_name:            ENV["SMTP_USERNAME"],
    password:             ENV["SMTP_PASSWORD"],
    authentication:       :plain,
    enable_starttls_auto: true
  }
  config.action_mailer.default_options  = { from: ENV["MAILER_FROM"] }
  config.action_mailer.default_url_options = { host: "rocky-cove-15980-acbcac59777d.herokuapp.com" }
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = false
end
