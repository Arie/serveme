Feature: Managing donators
  As an admin
  I want to manage donators
  So I don't have to do this through the console

  Background:
    Given I am logged in
    And I am an admin
    And there is a non-donator

  Scenario: Adding a donator
    When I go add a donator
    And I enter his uid
    And I save the donator
    Then I see the new donator in the list

  Scenario: Editing a donator
    Given there is a donator
    When I edit the donator
    And I change the expiration date
    Then I can see the new expiration date

