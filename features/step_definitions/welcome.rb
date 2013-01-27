When /^I go to the welcome page$/ do
  visit '/'
end

Then /^I can view a list of current reservations$/ do
  page.should have_content @reservation.user.nickname
  page.should have_content @reservation.server.name
end

Given /^I have made a reservation that is currently active$/ do
  @reservation = create(:reservation, :user => @current_user, :starts_at => Time.current, :ends_at => 1.hour.from_now, :provisioned => true, :server => Server.first)
end

Then /^I can view my reservation in the list$/ do
  within 'table.your-reservations' do
    page.should have_content @reservation.server.name
  end
end
