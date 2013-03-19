# encoding: utf-8
Given "there are reservations today" do
  create(:reservation, :server => Server.last, :starts_at => 4.hours.from_now, :ends_at => 5.hours.from_now)
  @reservation = create(:reservation, :server => Server.first, :starts_at => 5.hours.from_now, :ends_at => 6.hours.from_now)
end

When "I go make a reservation" do
  visit '/reservations/server_selection'
end

Then "I get to select a server" do
  Server.all.each do |server|
    page.should have_content server.name
  end
end

Then "I can see the current reservations per server" do
  Server.all.each do |server|
    server.reservations.each do |reservation|
      page.should have_content I18n.l(reservation.starts_at, :format => :short_with_dayname)
    end
  end
end

When "I select a server" do
  @server = Server.first
  within "#local_server_#{@server.id}" do
    click_link "Book this server"
  end
end

Then "I get to enter the reservation details" do
  page.should have_content "Password"
  page.should have_content "Rcon"
  page.should have_content "Start/end time"
end

When "I don't enter any reservation details" do
  click_button "Save"
end

When "I enter the reservation details" do
  step "I go make a reservation"
  step "I select a server"

  fill_in "Password", :with => "secret"
  fill_in "Rcon",     :with => "even more secret"
end

Then "I see the errors for the missing reservation fields" do
  page.should have_content "can't be blank"
end

Then "I can see my reservation on the welcome page" do
  @reservation = @current_user.reservations.last
  step "I can view my reservation in the list"
end

When "I enter the reservation details for a future reservation" do
  step "I enter the reservation details"

  fill_in "Start/end time",       :with => I18n.l(3.hours.from_now, :format => :datepicker)
  fill_in "reservation_ends_at", :with => I18n.l(4.hours.from_now, :format => :datepicker)
end

When "I save the reservation" do
  step "the server gets killed"
  click_button "Save"
end

Then "the server gets killed" do
  LocalServer.any_instance.should_receive(:find_process_id).and_return { 12345 }
  Process.should_receive(:kill).with(15, 12345)
end

Then "the server does not get killed" do
  Server.any_instance.should_not_receive(:find_process_id)
  Process.should_not_receive(:kill)
end

When "I save the future reservation" do
  step "the server does not get killed"
  click_button "Save"
end

Then "I cannot end the reservation" do
  within "#reservation_#{@reservation.id}" do
    page.should_not have_content "End reservation"
  end
end

Then "I can cancel the reservation" do
  within "#reservation_#{@reservation.id}" do
    page.should have_content "Cancel reservation"
  end
end

Given "there is a future reservation" do
  step "I enter the reservation details for a future reservation"
  step "I save the future reservation"
end

When "I cancel the future reservation" do
  step "the server does not get killed"
  @reservation = @current_user.reservations.last
  within "#reservation_#{@reservation.id}" do
    click_link "Cancel reservation"
  end
end

Then "I am notified the reservation was cancelled" do
  page.should have_content('cancelled')
end

Given "there is a reservation that will end within the hour" do
  @reservation = create(:reservation, :user => @current_user, :starts_at => 5.minutes.ago, :ends_at => 55.minutes.from_now, :provisioned => true)
end

Given "a reservation that starts shortly after mine" do
  create(:reservation, :server => @reservation.server, :starts_at => @reservation.ends_at + 5.minutes)
end

Then "I get notified extending failed" do
  page.should have_content "Could not extend"
end

When "I extend my reservation" do
  step "I go to the welcome page"
  click_link "Extend reservation"
end

Then "the reservation's end time is an hour later" do
end

Then "I get notified that the reservation was extended" do
  page.should have_content "Reservation extended"
end

Then "I can control my reservation" do
  within 'table.your-reservations' do
    page.should have_content "End reservation"
  end
end

Then "I can open the details of my reservation" do
  within 'table.your-reservations' do
    click_link "Show reservation"
  end
end

Then "I can see the details of my reservation" do
  server = @reservation.server
  page.should have_content "#{server.server_connect_string(@reservation.password)}"
  page.should have_content "#{server.stv_connect_string(@reservation.tv_password)}"
end

Given "I have a running reservation" do
  @reservation = create(:reservation, :user => @current_user, :provisioned => true)
end

When "I end my reservation" do
  step "I go to the welcome page"
  step "the server gets killed"
  @reservation_zipfile_name = @reservation.zipfile_name
  within "#reservation_#{@reservation.id}" do
    click_link "End reservation"
  end
end

Then "I get notice and a link with the demos and logs" do
  page.should have_content "Reservation removed"
  within '.flash.alert' do
    find('a')[:href].should include(@reservation_zipfile_name)
  end
end

When "I go to the reservations listing" do
  visit '/reservations'
end

Then "I see the details of my reservations" do
  @current_user.reservations.each do |reservation|
    within "#reservation_#{reservation.id}" do
      find('a.btn-success')[:href].should include(reservation.id.to_s)
    end
  end
end

Then "I can open the logs page" do
  click_link "logs.tf"
end

When "I go to the logs page for the reservation" do
  visit reservation_log_uploads_path(@reservation)
end

When "I check a log" do
  click_link "Read log"
end

When "I choose to upload the log" do
  click_link "Send to logs.tf"
end

Then "I get a notice that I didn't enter my API key yet" do
  page.should have_content "You haven't entered your logs.tf API key yet"
end

Given "I have a logs.tf API key" do
  @current_user.update_attributes(:logs_tf_api_key => 'foobar')
end

Then "I don't get the API key notice" do
  page.should_not have_content "You haven't entered your logs.tf API key yet"
end

Then "I can see if it's the log file I want to upload" do
  page.should have_content("Please check that the settings are correct for this game mode")
end

Given "my reservation had a log" do
  step "my reservation had a log with special characters"
end

Then "I can see it's pretty special" do
  page.should have_content("]ρтqяσx[ Psycho Killer")
  page.should have_content("CคpTคiИ★Lucky")
  page.should have_content("Λϟ ϟλϟ ϟIИØ™")
  page.should have_content("Dança, Dança")
end

Given "my reservation had a log with special characters" do
  dir = Rails.root.join("server_logs", "#{@reservation.id}")
  FileUtils.mkdir_p(dir)
  FileUtils.cp(Rails.root.join('spec', 'fixtures', 'logs', 'special_characters.log'), File.join(dir, "L1337.log"))
end


Then "I get to enter the upload details" do
  fill_in "Title",  :with => "Epsilon destroying Broder"
  fill_in "Map",    :with => "every map"
end
