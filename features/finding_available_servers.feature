Feature: Finding an available server
  As a user
  I want to find an available server
  So I can make a reservation for it

  Background:
    Given I am logged in
    And there are reservations today

  Scenario: Selecting a server
    When I go make a reservation
    Then I get to select a server
    And I can see the current reservations per server

  Scenario: Finding an available server
    When I go make a reservation
    And I enter a date and time on which there is a server available
    And I try to find an available server
    Then I get to enter the reservation details

  Scenario: Failing to find an available server
    When I go make a reservation
    And I enter a date and time on which there is no server available
    And I try to find an available server
    Then I get notified there are no servers available

  Scenario: Finding a free server during a reservation of myself
    When I go make a reservation
    And I enter a date and time on which I already have a reservation
    And I try to find an available server
    Then I get notified I already have a reservation
