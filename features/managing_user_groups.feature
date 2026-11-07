Feature: Managing user groups
  As an admin
  I want to find users and change their groups
  So I can hand out league admin access

  Background:
    Given I am logged in
    And I am an admin
    And there is a non-donator

  Scenario: Finding a user and adding them to a group
    When I look up the user "Future"
    And I add the user to the "League Admins" group until "2100-10-10T10:10"
    Then the user is a league admin until "2100-10-10 10:10"

  Scenario: Removing a user from a group
    Given the user is a league admin
    When I edit the user
    And I remove the user from the "League Admins" group
    Then the user is no longer a league admin

  Scenario: Looking up an unknown user
    When I look up the user "Nobody"
    Then I am told the user was not found
