Feature: Uploading a map
  As a player
  I want to upload a map
  So I can always play the one I want

  Background:
    Given I am logged in

  Scenario: Trying to upload without being a donator
    When I go to upload a map
    Then I get shown a message I should be a donator

  Scenario: Trying to upload a non-map file
    Given I am a donator
    And I go to upload a map
    When I try to upload a wrong kind of file
    Then I see a message the map file was invalid

  Scenario: Trying to upload a map that's already available
    Given I am a donator
    And I go to upload a map
    When I try to upload an existing map
    Then I see a message the map is already available

  Scenario: Succesfully uploading a map
    Given I am a donator
    And I go to upload a map
    When I upload a new map
    Then I see a message that the map upload was succesful
