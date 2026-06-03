require "factory_bot_rails"

World(FactoryBot::Syntax::Methods)

# ── Navigation ────────────────────────────────────────────────────────────────

Given("I am on the login page") do
  visit login_path
end

Given("I am on the signup page") do
  visit signup_path
end

Given("I am on the new person page") do
  visit new_person_path
end

Given("I am on the new event page") do
  visit new_event_path
end

When("I visit the people page") do
  visit people_path
end

When("I visit the events page for that month") do
  visit events_path(month: @event_month)
end

When("I visit the events page for the current month") do
  visit events_path(month: Date.current.strftime("%Y-%m"))
end

# ── Form interactions ─────────────────────────────────────────────────────────

When("I fill in {string} with {string}") do |label, value|
  fill_in label, with: value
end

# Disambiguate the "Email" label on person form from the navbar search field
When("I fill in person {string} with {string}") do |label, value|
  fill_in "person[#{label.downcase}]", with: value
end

When("I check {string}") do |locator|
  check locator
end

When("I click {string}") do |button|
  click_button button
end

When("I log out") do
  # DELETE /logout — submit via the logout button in the navbar
  find("form[action='#{logout_path}']").click_on("Log Out")
rescue Capybara::ElementNotFound
  # Fallback: submit directly
  page.driver.submit :delete, logout_path, {}
end

When("I select {string} as the medium") do |medium|
  # Medium is rendered as radio-button pills — find and click the one matching
  find("label.medium-pill", text: medium.titleize).click
rescue Capybara::ElementNotFound
  choose medium
end

When("I check participant {string}") do |name|
  # Participants are rendered as labelled checkboxes inside a fieldset
  check name
end

# ── Assertions ────────────────────────────────────────────────────────────────

Then("I should be on the dashboard") do
  expect(current_path).to eq(root_path).or eq(dashboard_path)
end

Then("I should be on the login page") do
  expect(current_path).to eq(login_path)
end

Then("I should be on the signup page") do
  expect(current_path).to eq(signup_path)
end

Then("I should see {string}") do |text|
  expect(page).to have_content(text)
end

Then("I should not see {string}") do |text|
  expect(page).not_to have_content(text)
end

# ── Data setup ────────────────────────────────────────────────────────────────

Given("a registered user with email {string} and password {string}") do |email, password|
  @current_user = create(:user, email: email, password: password,
                                password_confirmation: password)
end

Given("I am logged in as {string} with password {string}") do |email, password|
  visit login_path
  fill_in "Email", with: email
  fill_in "Password", with: password
  click_button "Log In"
end

Given("a contact named {string} exists for the current user") do |name|
  @person = create(:person, name: name, user: @current_user)
end

Given("another user has a contact named {string}") do |name|
  other = create(:user, email: "other_#{SecureRandom.hex(4)}@example.com",
                        password: "Secure1!password",
                        password_confirmation: "Secure1!password")
  create(:person, name: name, user: other)
end

Given("an event with title {string} exists for the current user") do |title|
  event = create(:event, title: title, user: @current_user,
                         occurred_at: Time.current)
  @event_month = event.occurred_at.strftime("%Y-%m")
end

Given("another user has an event titled {string}") do |title|
  other = create(:user, email: "other_#{SecureRandom.hex(4)}@example.com",
                        password: "Secure1!password",
                        password_confirmation: "Secure1!password")
  create(:event, title: title, user: other, occurred_at: Time.current)
end
