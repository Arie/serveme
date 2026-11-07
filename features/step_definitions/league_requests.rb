# typed: false
# frozen_string_literal: true

Given 'I am a league admin' do
  @current_user.group_ids += [ Group.league_admin_group.id ]
end

Given 'there is a player with an alt on the same IP' do
  create(:reservation_player, steam_uid: '76561198000000001', name: 'Main Account', ip: '82.168.10.20')
  create(:reservation_player, steam_uid: '76561198000000002', name: 'Alt Account', ip: '82.168.10.20')
end

When 'I go to the league request page' do
  visit league_request_path
end

When 'I search for the player' do
  step 'I go to the league request page'
  fill_in 'Steam ID 64', with: '76561198000000001'
  click_button 'Search'
end

When 'I search for the player with cross referencing' do
  step 'I go to the league request page'
  fill_in 'Steam ID 64', with: '76561198000000001'
  check 'Cross reference results'
  click_button 'Search'
end

Then 'I see the player and their alt' do
  page.should have_content '2 search results'
  page.should have_content 'Main Account'
  page.should have_content 'Alt Account'
end

Then 'I see the player but not their alt' do
  page.should have_content '1 search results'
  page.should have_content 'Main Account'
  page.should_not have_content 'Alt Account'
end
