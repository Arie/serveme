# typed: false
# frozen_string_literal: true

Given 'I have an active cloud server' do
  @active_cloud_reservation = create(:reservation, user: @current_user, server: create(:cloud_server))
end

When 'I go launch a cloud server' do
  visit new_cloud_reservation_path
end

When 'I pick a cloud location and launch' do
  select 'Falkenstein (Hetzner)', from: 'cloud_location'
  fill_in 'Password', with: 'secret'
  fill_in 'Rcon', with: 'even more secret'
  click_button 'Launch'
end

Then 'my cloud server is being provisioned' do
  reservation = @current_user.reservations.reload.last
  expect(reservation.server).to be_a(CloudServer)
  expect(reservation.server.cloud_location).to eq('fsn1')
  expect(page).to have_current_path(reservation_path(reservation))
  expect(page).to have_content 'Cloud server is being provisioned'
end

Then 'I am sent to my active cloud server' do
  expect(page).to have_current_path(reservation_path(@active_cloud_reservation))
  expect(page).to have_content 'You already have an active cloud server'
  expect(CloudServer.count).to eq(1)
end

Then 'I am told cloud servers are for Premium users' do
  expect(page).to have_current_path(root_path)
  expect(page).to have_content 'Cloud servers are available to Premium users.'
end
