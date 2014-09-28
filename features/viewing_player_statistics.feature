Feature: Viewing player statistics
  As an admin
  I want to view player statistics
  So I can see the servers' performance

  Background:
    Given I am logged in
    And I am an admin
    And there are player statistics
    And I go to the player statistics

  Scenario: Viewing one player's statistics
    When I click on a player's name
    Then I see all the player's statistics

  Scenario: Viewing one player's statistics for a reservation
    When I click on a player's ping
    Then I see the player's statistics for the reservation

  Scenario: Viewing all players' statistics for a reservation
    When I click on a player statistic's date
    Then I see player statistics for that reservation

  Scenario: Viewing all players' statistics for a server
    When I click on a player statistic's server name
    Then I see player statistics for that server
