Feature: Buying donator status
  As a user
  I want to buy donator status
  So I unlock more features of serveme.tf

  Background:
    Given I am logged in
    And there are products
    And I go to the welcome page

    @vcr
  Scenario: Buying 1 month of donator status
    When I buy 1 month worth of donator status
    And my PayPal payment was successful
    Then my donator status lasts for a month

    @vcr
  Scenario: Buying 1 year of donator status
    When I buy 1 year worth of donator status
    And my PayPal payment was successful
    Then my donator status lasts for a year

