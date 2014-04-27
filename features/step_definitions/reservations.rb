# encoding: utf-8
Given "there are reservations today" do
  create(:reservation, :server => Server.last, :starts_at => 10.minutes.from_now, :ends_at => 1.hour.from_now)
  @reservation = create(:reservation, :server => Server.first, :starts_at => 130.minutes.from_now, :ends_at => 3.hours.from_now)
end

When "I go make a reservation" do
  visit new_reservation_path
end

Given "there are active and inactive servers" do
  @active_server    = create(:server, :name => "Active")
  @inactive_server  = create(:server, :name => "Inactive", :active => false)
end

Then "I get to select a server" do
  Server.active.each do |server|
    page.should have_content server.name
  end
  Server.inactive.each do |server|
    page.should_not have_content server.name
  end
end


Then "I get to select a donator server" do
  page.should have_content "Donator Only Server"
end


Then "I can see the current reservations per server" do
  Server.all.each do |server|
    server.reservations.each do |reservation|
      page.should have_content I18n.l(reservation.starts_at, :format => :short_with_dayname)
    end
  end
end

Then "I get to enter the reservation details" do
  page.should have_content "Password"
  page.should have_content "Rcon"
  page.should have_content "Starts at"
end

When "I don't enter any reservation details" do
  click_button "Save"
end

When "I leave important reservation fields blank" do
  fill_in "Password",       :with => ""
  fill_in "Rcon",           :with => ""
  click_button "Save"
end

When "I enter the reservation details" do
  step "I go make a reservation"

  fill_in "Server", :with => Server.first.id
  fill_in "Password", :with => "secret"
  fill_in "Rcon",     :with => "even more secret"
end

Then "I see the errors for the missing reservation fields" do
  page.should have_content "can't be blank"
end

Then "I can see my reservation on the welcome page" do
  @reservation = @current_user.reservations.reload.last
  step "I go to the welcome page"
  step "I can view my reservation in the list"
end

When "I enter the reservation details for a future reservation" do
  step "I enter the reservation details"

  fill_in "Starts at",      :with => I18n.l(30.minutes.from_now, :format => :datepicker)
  fill_in "Ends at", :with => I18n.l(1.hour.from_now,     :format => :datepicker)
end

When "I go edit my reservation" do
  visit edit_reservation_path(@reservation)
end

When "I edit my reservation" do
  step "I go edit my reservation"
  @ends_at = @reservation.starts_at + 90.minutes
  fill_in "reservation_ends_at", :with => I18n.l(@ends_at, :format => :datepicker)
  click_button "Save"
end

When "I edit my reservation's password" do
  step "I go edit my reservation"
  fill_in "Password", :with => "newpassword"
  click_button "Save"
end

Then "the reservation's password is updated" do
  @reservation.reload.password.should == 'newpassword'
end

Then "I see my changes will be in effect after a map change" do
  page.should have_content "your changes will be active after a mapchange"
end

Then "I see the new reservation details in the list" do
  page.should have_content(I18n.l(@ends_at, :format => :short))
end

When "I save the reservation" do
  click_button "Save"
end

When "I save the future reservation" do
  click_button "Save"
end

Then "I cannot end the reservation" do
  within "#reservation_#{@reservation.id}" do
    page.should_not have_content "End reservation"
  end
end

Then "I can cancel the reservation" do
  within "#reservation_#{@reservation.id}" do
    page.should have_content "Cancel"
  end
end

Given "there is a future reservation" do
  step "I enter the reservation details for a future reservation"
  step "I save the future reservation"
end

When "I cancel the future reservation" do
  @reservation = @current_user.reservations.reload.last
  within "#reservation_#{@reservation.id}" do
    click_link "Cancel"
  end
end

Then "I am notified the reservation was cancelled" do
  page.should have_content('cancelled')
end

Given "there is a reservation that will end within the hour" do
  @reservation = create(:reservation, :user => @current_user, :starts_at => 5.minutes.ago, :ends_at => 55.minutes.from_now, :provisioned => true)
end

Given "a reservation that starts shortly after mine" do
  create(:reservation, :server => @reservation.server, :starts_at => @reservation.ends_at + 5.minutes, :ends_at => @reservation.ends_at + 1.hour)
end

Then "I get notified extending failed" do
  page.should have_content "Could not extend"
end

When "I extend my reservation" do
  step "I go to the welcome page"
  click_link "Extend"
end

Then "the reservation's end time is an hour later" do
end

Then "I get notified that the reservation was extended" do
  page.should have_content "Reservation extended"
end

Then "I can control my reservation" do
  within 'table.your-reservations' do
    page.should have_content "End"
  end
end

Then "I can open the details of my reservation" do
  step "I go to the welcome page"
  within 'table.your-reservations' do
    click_link "Details"
  end
end

Then "I can see the details of my reservation" do
  server = @reservation.server
  page.should have_content "#{server.server_connect_string(@reservation.password)}"
  page.should have_content "#{server.stv_connect_string(@reservation.tv_password)}"
end

Given "I have a future reservation" do
  step "there is a future reservation"
  @reservation = Reservation.last
end
Given "I have a running reservation" do
  start_reservation(10.minutes.ago)
end

Given "I have a reservation that has just started" do
  start_reservation(Time.current)
end

def start_reservation(starts_at)
  @reservation = create(:reservation, :user => @current_user, :provisioned => true, :starts_at => starts_at)
end

When "I try to end my reservation" do
  step "I go to the welcome page"
  @reservation_zipfile_name = @reservation.zipfile_name
  within "#reservation_#{@reservation.id}" do
    click_link "End"
  end
end

When "I end my reservation" do
  step "I try to end my reservation"
end

Given "the end reservations job has run" do
  Reservation.last.end_reservation
end

Then "I get told I should wait before ending" do
  page.should have_content "was started in the last 2 minutes"
end

Then "I get a notice and a link with the demos and logs" do
  page.should have_content "Reservation removed"
  within '.flash_message' do
    find('a')[:href].should include(@reservation_zipfile_name)
  end
end

When "I go to the reservations listing" do
  visit '/reservations'
end

Then "I see the details of my reservations" do
  @current_user.reservations.reload.each do |reservation|
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

Then "I can see it's very special" do
  page.should have_content("★radist★")
  page.should have_content("Çàïèñü ïîù¸ëú")
end

Given "my reservation had a log with special characters" do
  dir = Rails.root.join("server_logs", "#{@reservation.id}")
  FileUtils.mkdir_p(dir)
  FileUtils.cp(Rails.root.join('spec', 'fixtures', 'logs', 'special_characters.log'), File.join(dir, "L1337.log"))
end

Given "my reservation had a log with very special characters" do
  dir = Rails.root.join("server_logs", "#{@reservation.id}")
  FileUtils.mkdir_p(dir)
  FileUtils.cp(Rails.root.join('spec', 'fixtures', 'logs', 'very_special_characters.log'), File.join(dir, "L1337.log"))
end

Then "I get to enter the upload details" do
  fill_in "Title",  :with => "Epsilon destroying Broder"
  fill_in "Map",    :with => "every map"
end
