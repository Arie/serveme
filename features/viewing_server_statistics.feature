Feature: Viewing server statistics
  As an admin
  I want to view server statistics
  So I can see the servers' performance

  Background:
    Given I am logged in
    And I am an admin
    And there are server statistics
    And I go to the server statistics

  Scenario: Viewing one server's statistics
    When I click on a server's name
    Then I see all the server's statistics

  Scenario: Viewing one server's statistics for a reservation
    When I click on a server's date
    Then I see the server's statistics for the reservation
