Feature: Launching a cloud server
  As a donator
  I want to launch a cloud server in a location of my choice
  So I can play close to my opponents

  Background:
    Given I am logged in

  Scenario: Launching a cloud server
    Given I am a donator
    When I go launch a cloud server
    And I pick a cloud location and launch
    Then my cloud server is being provisioned

  Scenario: Launching a second cloud server
    Given I am a donator
    And I have an active cloud server
    When I go launch a cloud server
    And I pick a cloud location and launch
    Then I am sent to my active cloud server

  Scenario: Non-donators can't launch cloud servers
    When I go launch a cloud server
    Then I am told cloud servers are for Premium users
