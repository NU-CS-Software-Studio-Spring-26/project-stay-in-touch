Feature: Logging catch-up events
  As a logged-in user
  I want to log catch-up events with my contacts
  So that I can track how recently I've been in touch

  Background:
    Given a registered user with email "user@example.com" and password "Secure1!password"
    And I am logged in as "user@example.com" with password "Secure1!password"
    And a contact named "Sam Rivera" exists for the current user

  Scenario: Scheduling an event successfully
    Given I am on the new event page
    When I select "call" as the medium
    And I check participant "Sam Rivera"
    And I click "Schedule Catch-Up"
    Then I should see "Sam Rivera"

  Scenario: Scheduling an event without selecting a medium
    Given I am on the new event page
    When I check participant "Sam Rivera"
    And I click "Schedule Catch-Up"
    Then I should see "is not included in the list"

  Scenario: Viewing the events index
    Given an event with title "Birthday call" exists for the current user
    When I visit the events page for that month
    Then I should see "Birthday call"

  Scenario: Other users' events are not visible
    Given another user has an event titled "Secret Meetup"
    When I visit the events page for the current month
    Then I should not see "Secret Meetup"
