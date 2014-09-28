Given "there are server statistics" do
  server = create :server, :name => "the right server"
  reservation = create :reservation, :server => server
  @stat = create :server_statistic, :server => server,        :reservation => reservation, :fps => 1337
  create :server_statistic, :server => server,  :fps => 1338
  other_server = create :server, :name => "other server"
  other_reservation = create :reservation, :server => other_server
  create :server_statistic, :server => other_server,  :reservation => other_reservation, :fps => 1234
end

Given "I go to the server statistics" do
  visit server_statistics_path
end

When "I click on a server's name" do
  within "tr#server_statistic_#{@stat.id}" do
    click_link "the right server"
  end
end

Then "I see all the server's statistics" do
  page.should have_content "1337"
  page.should have_content "1338"
end

Then "I see the server's statistics for the reservation" do
  page.should have_content "the right server"
  page.should have_content "1337"
  page.should_not have_content "other server"
  page.should_not have_content "1338"
end

When "I click on a server's date" do
  within "tr#server_statistic_#{@stat.id}" do
    page.find("a.server_reservation_statistics").click
  end
end
