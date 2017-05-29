Feature: Viewing info for streamers
  As a streamer
  I want to view reservation information
  So I can set up the stream

  Background:
    Given I am logged in
    And I am a streamer
    And there are reservations today

  Scenario: Checking reservation info
    When I go to the recent reservations listing
    Then I see the action buttons of all reservations

