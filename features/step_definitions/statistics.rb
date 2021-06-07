# frozen_string_literal: true

When 'I go view the statistics' do
  visit statistics_pages_path
end

Then 'I can see the most active users' do
  page.should have_content Reservation.last.user.nickname
end
