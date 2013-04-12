Feature: Editing reservations
  As a user
  I want to edit my reservation
  So I can play the next map with different settings

  Background:
    Given I am logged in

  Scenario: Editing a future reservation
    Given I have a future reservation
    When I edit my reservation
    Then I see the new reservation details in the list

  Scenario: Editing a running reservation
    Given I have a running reservation
    When I edit my reservation's password
    Then the reservation's password is updated

  Scenario: Unsuccesfully editing a reservation
    Given I have a future reservation
    When I go edit my reservation
    And I leave important reservation fields blank
    Then I see the errors for the missing reservation fields
