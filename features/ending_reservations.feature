Feature: Ending reservations
  As a user
  I want to end my reservation
  So I can collect my demos and logs

  Background:
    Given I am logged in

  Scenario: Ending a reservation
    Given I have a running reservation
    When I end my reservation
    Then I get a notice and a link with the demos and logs

  Scenario: Ending a reservation that has just started
    Given I have a reservation that has just started
    When I try to end my reservation
    Then I get told I should wait before ending

  Scenario: Cancelling a future reservation
    Given there is a future reservation
    And I go to the welcome page
    When I cancel the future reservation
    Then I am notified the reservation was cancelled
