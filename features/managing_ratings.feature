Feature: Managing ratings
  As an admin
  I want to manage ratings
  So I don't have to do this through the console

  Background:
    Given I am logged in
    And I am an admin
    And there is a rating
    And I go to the ratings

  Scenario: Publishing a rating
    When I publish a rating
    Then I see the rating is published

  Scenario: Unpublishing a rating
    Given there is a published rating
    And I go to the ratings
    When I unpublish a rating
    Then I see the rating is unpublished

  Scenario: Destroying a rating
    When I destroy the rating
    Then I can't see the rating

