Given "there are player statistics" do
  server = create :server, :name => "the server"
  @ps = create :player_statistic, :name => "the player", :created_at => Time.new(2014, 9, 27, 13, 0), :ping => 1337, :server => server
  create :player_statistic, :name => "the player", :created_at => Time.new(2014, 9, 27, 14, 0), :ping => 1338

  other_server = create :server, :name => "other server", :ip => "foo.bar"
  create :player_statistic, created_at: Time.new(2014, 9, 27, 12, 0), name: "player on other server", server: other_server

  create :player_statistic, created_at: Time.new(2014, 9, 27, 12, 0), steam_uid: "1337", name: "other player", server: @ps.server
end

Given "I go to the player statistics" do
  visit player_statistics_path
end

When "I click on a player's ping" do
  click_link "1337"
end

When "I click on a player's name" do
  within "tr#player_statistic_#{@ps.id}" do
    click_link "the player"
  end
end

Then "I see all the player's statistics" do
  page.should have_content "1337"
  page.should have_content "1338"
end

Then "I see the player's statistics for the reservation" do
  page.should have_content "the player"
  page.should have_content "1337"
  page.should_not have_content "player on other server"
  page.should_not have_content "other player"
end

When "I click on a player statistic's date" do
  click_link "Sat 27 Sep 13:00:00"
end

Then "I see player statistics for that reservation" do
  page.should have_content "Sat 27 Sep 13:00:00"
  page.should_not have_content "Sat 27 Sep 12:00:00"
end

When "I click on a player statistic's server name" do
  within "tr#player_statistic_#{@ps.id}" do
    click_link "the server"
  end
end

Then "I see player statistics for that server" do
  within "tr#player_statistic_#{@ps.id}" do
    page.should have_content "the server"
  end
  page.should_not have_content "other server"
end
