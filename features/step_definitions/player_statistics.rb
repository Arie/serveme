# frozen_string_literal: true

Given 'there are player statistics' do
  server = create :server, name: 'the right server'
  reservation = create :reservation, server: server
  rp = create :reservation_player, name: 'the right player', reservation: reservation, ip: '8.8.8.8', steam_uid: '1234'
  @ps = create :player_statistic, created_at: Time.zone.local(2014, 9, 27, 13, 0), ping: 1337, reservation_player: rp
  later_rp = create :reservation_player, name: 'the right player', steam_uid: '1234', reservation: create(:reservation, server: server, starts_at: 3.hours.from_now, ends_at: 5.hours.from_now)
  create :player_statistic, created_at: Time.zone.local(2014, 9, 27, 14, 0), ping: 1338, reservation_player: later_rp

  other_rp = create :reservation_player, name: 'player on other server', steam_uid: '1337'
  create :player_statistic, created_at: Time.zone.local(2014, 9, 27, 12, 0), reservation_player: other_rp

  same_reservation_other_player = create :reservation_player, name: 'other player', reservation: reservation, steam_uid: '1337'
  create :player_statistic, created_at: Time.zone.local(2014, 9, 27, 13, 0), reservation_player: same_reservation_other_player
end

Given 'I go to the player statistics' do
  visit player_statistics_path
end

When "I click on a player's ping" do
  click_link '1337'
end

When "I click on a player's name" do
  within "tr#player_statistic_#{@ps.id}" do
    click_link 'the right player'
  end
end

Then "I see all the player's statistics" do
  page.should have_content '1337'
  page.should have_content '1338'
end

Then "I see the player's statistics for the reservation" do
  page.should have_content 'the right player'
  page.should have_content '1337'
  page.should_not have_content 'player on other server'
  page.should_not have_content 'other player'
end

When "I click on a player statistic's date" do
  within "tr#player_statistic_#{@ps.id}" do
    page.find('a.player_reservation_statistics').click
  end
end

Then 'I see player statistics for that reservation' do
  page.should have_content 'Sat 27 Sep 13:00:00'
  page.should_not have_content 'Sat 27 Sep 12:00:00'
end

When "I click on a player statistic's server name" do
  within "tr#player_statistic_#{@ps.id}" do
    click_link 'the right server'
  end
end

Then 'I see player statistics for that server' do
  within "tr#player_statistic_#{@ps.id}" do
    page.should have_content 'the right server'
  end
  page.should_not have_content 'other server'
end
