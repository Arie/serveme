When /^I go to the welcome page$/ do
  visit '/'
end

Given "there are servers" do
  create(:server)
  Group.donator_group.servers << create(:server)
end

Then /^I can view a list of current reservations$/ do
  page.should have_content @reservation.user.nickname
  page.should have_content @reservation.server.name
end

Given /^I have made a reservation that is currently active$/ do
  @reservation = create(:reservation, :user => @current_user, :starts_at => 1.minute.ago, :ends_at => 1.hour.from_now, :provisioned => true, :server => Server.first)
end

Then /^I can view my reservation in the list$/ do
  within 'table.your-reservations' do
    page.should have_content @reservation.server.name
  end
end

Then "I see a count of free and donator-only servers" do
  page.should have_content "Everyone"
  page.should have_content "Premium"
end
