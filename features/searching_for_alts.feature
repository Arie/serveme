Feature: Searching for alts
  As a league admin
  I want to find accounts that played from the same IP
  So I can spot ban evaders

  Background:
    Given I am logged in
    And there is a player with an alt on the same IP

  Scenario: Cross referencing a player
    Given I am a league admin
    When I search for the player with cross referencing
    Then I see the player and their alt

  Scenario: Searching without cross referencing
    Given I am a league admin
    When I search for the player
    Then I see the player but not their alt

  Scenario: Regular users can't search
    When I go to the league request page
    Then I am sent back to the welcome page
