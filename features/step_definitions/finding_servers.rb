When "I enter a date and time on which there is a server available" do
  create :reservation, :starts_at => 3.hours.from_now, :ends_at => 5.hours.from_now

  fill_in "reservation_starts_at",    :with => I18n.l(1.hours.from_now, :format => :datepicker)
  fill_in "reservation_ends_at",      :with => I18n.l(2.hours.from_now, :format => :datepicker)
end

When "I enter a date and time on which there is no server available" do
  Server.destroy_all
  create :reservation, :server => create(:server), :starts_at => 3.hours.from_now, :ends_at => 5.hours.from_now
  fill_in "reservation_starts_at",    :with => I18n.l(2.hours.from_now, :format => :datepicker)
  fill_in "reservation_ends_at",      :with => I18n.l(4.hours.from_now, :format => :datepicker)
end

Then "I get notified there are no servers available" do
  page.should have_content("No servers available in the given timerange")
end

When "I enter a date and time on which I already have a reservation" do
  create :reservation, :user => @current_user, :starts_at => 1.hour.from_now, :ends_at => 3.hours.from_now
  create :server
  fill_in "reservation_starts_at",    :with => I18n.l(2.hours.from_now, :format => :datepicker)
  fill_in "reservation_ends_at",      :with => I18n.l(4.hours.from_now, :format => :datepicker)
end

When "I try to find an available server" do
  click_button "Find available server"
end
Then "I get notified I already have a reservation" do
  page.should have_content("you already have a reservation in this timeframe")
end

