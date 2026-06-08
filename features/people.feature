Feature: Managing contacts (People)
  As a logged-in user
  I want to add and manage my contacts
  So that I can keep track of who I want to stay in touch with

  Background:
    Given a registered user with email "user@example.com" and password "Secure1!password"
    And I am logged in as "user@example.com" with password "Secure1!password"

  Scenario: Adding a contact successfully
    Given I am on the new person page
    When I fill in "Name" with "Jordan Smith"
    And I fill in person "Email" with "jordan@example.com"
    And I click "Create Person"
    Then I should see "Jordan Smith"

  Scenario: Adding a contact with a missing name
    Given I am on the new person page
    When I fill in person "Email" with "jordan@example.com"
    And I click "Create Person"
    Then I should see "can't be blank"

  Scenario: Adding a contact with an invalid email
    Given I am on the new person page
    When I fill in "Name" with "Jordan Smith"
    And I fill in person "Email" with "not-an-email"
    And I click "Create Person"
    Then I should see "is invalid"

  Scenario: Viewing the contacts list
    Given a contact named "Taylor Jones" exists for the current user
    When I visit the people page
    Then I should see "Taylor Jones"

  Scenario: Other users' contacts are not visible
    Given another user has a contact named "Private Contact"
    When I visit the people page
    Then I should not see "Private Contact"

  Scenario: The reach-out panel summarises many overdue contacts (#184)
    Given 4 contacts are overdue for the current user
    When I visit the people page
    Then I should see "4 people"
    And I should see "View all 4"
