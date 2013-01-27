Feature: Listing my reservations
  As a user
  I want to see a list of my reservations
  So I can download old demos/logs and check current reservations

  Background:
    Given I am logged in

  Scenario: Viewing my reservations
    Given I have a running reservation
    And there is a future reservation
    When I go to the reservations listing
    Then I see the details of my reservations
