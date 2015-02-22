Feature: Viewing the welcome page


  Scenario: Viewing available servers
    Given there are servers
    When I go to the welcome page
    Then I see a count of free and donator-only servers

  Scenario: Viewing my own current reservation
    Given I am logged in
    And I have made a reservation that is currently active
    When I go to the welcome page
    Then I can view my reservation in the list
    And I can control my reservation
