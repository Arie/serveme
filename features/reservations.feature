Feature: Making a reservation

  Background:
    Given I am logged in
    And there are reservations today

  Scenario: Selecting a server
    When I go make a reservation
    Then I get to select a server
    And I can see the current reservations per server

  Scenario: Entering reservation details
    When I go make a reservation
    And I select a server
    Then I get to enter the reservation details

  Scenario: Unsuccesfully creating a reservation
    When I go make a reservation
    And I select a server
    And I don't enter any reservation details
    Then I see the errors for the missing reservation fields

  Scenario: Creating a reservation
    When I enter the reservation details
    And I save the reservation
    Then I can see my reservation on the welcome page
    And I can control my reservation

    @wip
  Scenario: Checking reservation info
    When I enter the reservation details
    And I save the reservation
    Then I can open the details of my reservation
    And I can see the details of my reservation

  Scenario: Creating a future reservation
    When I enter the reservation details for a future reservation
    And I save the future reservation
    Then I can see my reservation on the welcome page
    And I cannot end the reservation
    And I can cancel the reservation

  Scenario: Cancelling a future reservation
    Given there is a future reservation
    When I cancel the future reservation
    Then I am notified the reservation was cancelled

  Scenario: Extending a reservation
    Given there is a reservation that will end within the hour
    When I extend my reservation
    Then the reservation's end time is an hour later
    And I get notified that the reservation was extended
