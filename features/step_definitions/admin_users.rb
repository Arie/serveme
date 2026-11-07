# typed: false
# frozen_string_literal: true

Given 'the user is a league admin' do
  User.find_by!(uid: '1122334455').groups << Group.league_admin_group
end

When 'I look up the user {string}' do |input|
  visit new_admin_user_path
  fill_in 'Enter Steam ID or Nickname', with: input
  click_button 'Search'
end

When 'I edit the user' do
  visit edit_admin_user_path(User.find_by!(uid: '1122334455'))
end

When 'I add the user to the {string} group until {string}' do |group, expires_at|
  click_button 'View User'
  click_link 'Edit User'
  select group, from: 'group_id'
  fill_in 'expires_at', with: expires_at
  click_button 'Add to Group'
  page.should have_content "User added to #{group}"
end

When 'I remove the user from the {string} group' do |group|
  within('li', text: group) { click_button 'Remove' }
  page.should have_content "User removed from #{group}"
end

Then 'the user is a league admin until {string}' do |expires_at|
  page.should have_content expires_at
  expect(User.find_by!(uid: '1122334455')).to be_league_admin
end

Then 'the user is no longer a league admin' do
  expect(User.find_by!(uid: '1122334455')).not_to be_league_admin
end

Then 'I am told the user was not found' do
  page.should have_content 'No users found matching your search.'
end
