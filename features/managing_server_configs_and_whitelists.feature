Feature: Managing server configs and whitelists
  As an admin
  I want to manage the league configs and whitelists
  So players can pick them for their reservations

  Background:
    Given I am logged in

  Scenario: Adding and hiding a server config
    Given I am an admin
    When I add the server config "rgl_test_config"
    Then players can pick the server config "rgl_test_config"
    When I hide the server config "rgl_test_config"
    Then players can no longer pick the server config "rgl_test_config"

  Scenario: Adding and hiding a whitelist
    Given I am an admin
    When I add the whitelist "rgl_test_whitelist.txt"
    Then players can pick the whitelist "rgl_test_whitelist.txt"
    When I hide the whitelist "rgl_test_whitelist.txt"
    Then players can no longer pick the whitelist "rgl_test_whitelist.txt"

  Scenario: Regular users can't manage server configs
    When I go to the server configs page
    Then I am sent back to the welcome page
