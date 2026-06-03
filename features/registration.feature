Feature: User registration
  As a new visitor
  I want to create a Serendipity account
  So that I can start tracking my relationships

  Scenario: Successful registration
    Given I am on the signup page
    When I fill in "Email" with "newuser@example.com"
    And I fill in "Password" with "Secure1!password"
    And I fill in "Confirm Password" with "Secure1!password"
    And I check "user_terms_accepted"
    And I click "Sign Up"
    Then I should be on the dashboard
    And I should see "People"

  Scenario: Registration with mismatched passwords
    Given I am on the signup page
    When I fill in "Email" with "newuser@example.com"
    And I fill in "Password" with "Secure1!password"
    And I fill in "Confirm Password" with "Different1!password"
    And I check "user_terms_accepted"
    And I click "Sign Up"
    Then I should be on the signup page
    And I should see "doesn't match"

  Scenario: Registration with a weak password
    Given I am on the signup page
    When I fill in "Email" with "newuser@example.com"
    And I fill in "Password" with "short"
    And I fill in "Confirm Password" with "short"
    And I check "user_terms_accepted"
    And I click "Sign Up"
    Then I should be on the signup page
    And I should see "must be more than 10 characters"

  Scenario: Registration with a duplicate email
    Given a registered user with email "taken@example.com" and password "Secure1!password"
    And I am on the signup page
    When I fill in "Email" with "taken@example.com"
    And I fill in "Password" with "Secure1!password"
    And I fill in "Confirm Password" with "Secure1!password"
    And I check "user_terms_accepted"
    And I click "Sign Up"
    Then I should be on the signup page
    And I should see "has already been taken"

  Scenario: Registration without accepting terms
    Given I am on the signup page
    When I fill in "Email" with "newuser@example.com"
    And I fill in "Password" with "Secure1!password"
    And I fill in "Confirm Password" with "Secure1!password"
    And I click "Sign Up"
    Then I should be on the signup page
    And I should see "must be accepted"
