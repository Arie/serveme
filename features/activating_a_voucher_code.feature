Feature: Activating a premium code
  As a user
  I want to activate a premium code
  So I get my perks

  Background:
    Given I am logged in
    And there are products
    And I go to the welcome page

  Scenario: Activating a premium code
    When I go to activate a premium code
    And I enter a valid premium code
    Then my donator status lasts for a month

  Scenario: Activating an already used premium code
    When I enter a used premium code
    Then I see my premium code is no longer valid
