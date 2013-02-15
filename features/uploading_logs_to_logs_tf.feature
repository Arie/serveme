Feature: Uploading logs to logs.tf
  As a user
  I want to upload the server log to logs.tf
  So I can review my team's performance

  Background:
    Given I am logged in
    And I have a running reservation
    And I end my reservation

  Scenario: Going the logs screen
    When I go to the reservations listing
    Then I can open the logs page

    @logs
  Scenario: Checking a log before uploading
    Given my reservation had a log
    When I go to the logs page for the reservation
    And I check a log
    Then I can see if it's the log file I want to upload

    @logs
  Scenario: Checking a log with weird characters
    Given my reservation had a log with special characters
    When I go to the logs page for the reservation
    And I check a log
    Then I can see it's pretty special

    @logs
  Scenario: Going to upload a log without my own API key
    Given my reservation had a log
    When I go to the logs page for the reservation
    And I choose to upload the log
    Then I get a notice that I didn't enter my API key yet

    @logs
  Scenario: Going to upload a log with my own API key
    Given my reservation had a log
    And I have a logs.tf API key
    When I go to the logs page for the reservation
    And I choose to upload the log
    Then I don't get the API key notice

    @logs
  Scenario: Enter the details for the upload to logs.tf
    Given my reservation had a log
    When I go to the logs page for the reservation
    And I choose to upload the log
    Then I get to enter the upload details

