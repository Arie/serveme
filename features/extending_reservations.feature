Feature: Extending a reservation
  As a user
  I want to extend a reservation
  So I don't run out of time and get kicked from the server

  Background:
    Given I am logged in

  Scenario: Extending a reservation
    Given there is a reservation that will end within the hour
    When I extend my reservation
    Then the reservation's end time is an hour later
    And I get notified that the reservation was extended

  Scenario: Unsuccesfully extending a reservation
    Given there is a reservation that will end within the hour
    And a reservation that starts shortly after mine
    When I extend my reservation
    Then I get notified extending failed

