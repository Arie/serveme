Feature: Managing server
  As an admin
  I want to manage servers
  So I don't have to do this through the console

  Background:
    Given I am logged in
    And I am an admin

  Scenario: Adding a server
    When I go add a server
    And I enter the server attributes
    And I save the server
    Then I see the new server in the list

  Scenario: Editing a server
    When I go edit a server
    And I change the server name
    And I update the server
    Then I see the new server name in the list
