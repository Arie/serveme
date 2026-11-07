# typed: false
# frozen_string_literal: true

When 'I add the server config {string}' do |file|
  visit server_configs_path
  click_link 'Add server config'
  fill_in 'File name (without .cfg)', with: file
  click_button 'Save'
  page.should have_content 'Server config added'
end

When 'I hide the server config {string}' do |file|
  visit server_configs_path
  click_link file
  check 'Hidden'
  click_button 'Update'
  page.should have_content 'Server config updated'
end

When 'I add the whitelist {string}' do |file|
  visit whitelists_path
  click_link 'Add whitelist'
  fill_in 'File name (including .txt)', with: file
  click_button 'Save'
  page.should have_content 'Whitelist added'
end

When 'I hide the whitelist {string}' do |file|
  visit whitelists_path
  click_link file
  check 'Hidden'
  click_button 'Update'
  page.should have_content 'Whitelist updated'
end

Then 'players can pick the server config {string}' do |file|
  visit new_reservation_path
  page.should have_select 'reservation_server_config_id', with_options: [ file ]
end

Then 'players can no longer pick the server config {string}' do |file|
  visit new_reservation_path
  page.should have_select 'reservation_server_config_id'
  page.should_not have_select 'reservation_server_config_id', with_options: [ file ]
end

Then 'players can pick the whitelist {string}' do |file|
  visit new_reservation_path
  page.should have_select 'reservation_whitelist_id', with_options: [ file ]
end

Then 'players can no longer pick the whitelist {string}' do |file|
  visit new_reservation_path
  page.should have_select 'reservation_whitelist_id'
  page.should_not have_select 'reservation_whitelist_id', with_options: [ file ]
end

When 'I go to the server configs page' do
  visit server_configs_path
end

Then 'I am sent back to the welcome page' do
  page.should have_current_path(root_path)
end
