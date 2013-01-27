Feature: Ending reservations
  As a user
  I want to end my reservation
  So I can collect my demos and logs

  Background:
    Given I am logged in

  Scenario: Ending a reservation
    Given I have a running reservation
    When I end my reservation
    Then I get notice and a link with the demos and logs

  Scenario: Cancelling a future reservation
    Given there is a future reservation
    When I cancel the future reservation
    Then I am notified the reservation was cancelled

