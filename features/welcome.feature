Feature: Viewing the welcome page

  Scenario: Viewing current reservations
    Given there are reservations today
    When I go to the welcome page
    Then I can view a list of current reservations

  Scenario: Viewing my own current reservation
    Given I am logged in
    And I have made a reservation that is currently active
    When I go to the welcome page
    Then I can view my reservation in the list
    And I can control my reservation
