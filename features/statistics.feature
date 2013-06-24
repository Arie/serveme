Feature: Viewing statistics
  As an admin
  I want to see the site's statistics
  So I can see how the site is doing

  Background:
    Given I am logged in
    And there are reservations today

  Scenario: Viewing the statistics
    When I go view the statistics
    Then I can see the most active users
