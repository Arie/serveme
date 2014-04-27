Feature: Making a reservation
  As a user
  I want to make a reservation
  So I have a server to play on

  Background:
    Given I am logged in
    And there are reservations today

  Scenario: Entering reservation details
    When I go make a reservation
    Then I get to enter the reservation details

  Scenario: Creating a reservation
    When I enter the reservation details
    And I save the reservation
    Then I can see my reservation on the welcome page

  Scenario: Unsuccesfully creating a reservation
    When I go make a reservation
    And I don't enter any reservation details
    Then I see the errors for the missing reservation fields

  Scenario: Creating a future reservation
    When I enter the reservation details for a future reservation
    And I save the future reservation
    Then I can see my reservation on the welcome page
    And I cannot end the reservation
    And I can cancel the reservation

  Scenario: Checking reservation info
    When I enter the reservation details
    And I save the reservation
    Then I can open the details of my reservation
