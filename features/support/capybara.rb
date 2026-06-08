# Driver configuration for Capybara.
#
# The default driver is :rack_test (no browser) — fast, used by all scenarios
# except those tagged @javascript. Cucumber automatically switches @javascript
# scenarios to Capybara.javascript_driver, which we point at headless Chrome
# below so the Stimulus + Turbo-Frame UI is exercised in a real browser engine.
#
# Real Chrome sends a modern User-Agent, so it passes ApplicationController's
# `allow_browser versions: :modern` gate.
require "selenium-webdriver"

Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--disable-gpu")
  options.add_argument("--window-size=1400,1400")
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.javascript_driver = :headless_chrome

# Allow a little headroom for the debounced live-search to round-trip through
# Turbo before assertions run (Capybara retries until this timeout).
Capybara.default_max_wait_time = 5
