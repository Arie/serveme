Feature: Making a reservation
  As a user
  I want to make a reservation
  So I have a server to play on

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

  Scenario: Entering reservation details
    When I go make a reservation
    And I select a server
    Then I get to enter the reservation details

  Scenario: Creating a reservation
    When I enter the reservation details
    And I save the reservation
    Then I can see my reservation on the welcome page
    And I can control my reservation

  Scenario: Unsuccesfully creating a reservation
    When I go make a reservation
    And I select a server
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
    And I can see the details of my reservation

