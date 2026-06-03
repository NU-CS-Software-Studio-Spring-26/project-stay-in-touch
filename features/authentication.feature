Feature: User authentication
  As a registered user
  I want to log in and out of Serendipity
  So that my contacts remain private

  Background:
    Given a registered user with email "alice@example.com" and password "Secure1!password"

  Scenario: Successful login
    Given I am on the login page
    When I fill in "Email" with "alice@example.com"
    And I fill in "Password" with "Secure1!password"
    And I click "Log In"
    Then I should be on the dashboard
    And I should see "People"

  Scenario: Login with wrong password
    Given I am on the login page
    When I fill in "Email" with "alice@example.com"
    And I fill in "Password" with "WrongPassword1!"
    And I click "Log In"
    Then I should be on the login page
    And I should see "Invalid email or password"

  Scenario: Login with unknown email
    Given I am on the login page
    When I fill in "Email" with "nobody@example.com"
    And I fill in "Password" with "Secure1!password"
    And I click "Log In"
    Then I should be on the login page
    And I should see "Invalid email or password"

  Scenario: Accessing a protected page while logged out
    When I visit the people page
    Then I should be on the login page

  Scenario: Successful logout
    Given I am logged in as "alice@example.com" with password "Secure1!password"
    When I log out
    Then I should be on the login page
