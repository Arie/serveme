Feature: Activating a voucher code
  As a user
  I want to activate a voucher
  So I get my perks

  Background:
    Given I am logged in
    And there are products
    And I go to the welcome page

  Scenario: Activating a voucher
    When I go to activate a voucher
    And I enter a valid voucher code
    Then my donator status lasts for a month

  Scenario: Activating an already used voucher
    When I enter a used voucher code
    Then I see my voucher is no longer valid
