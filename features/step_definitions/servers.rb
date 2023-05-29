# frozen_string_literal: true

Given 'there is a donator only server' do
  @server = create :server, name: 'Donator Only Server', groups: [Group.donator_group]
end

When 'I go add a server' do
  visit new_server_path
end

When 'I go edit a server' do
  visit edit_server_path(Server.first.id)
end

When 'I enter the server attributes' do
  fill_in 'Name', with: 'This is the Server Name'
  fill_in 'IP', with: '127.0.0.1'
  fill_in 'Port', with: '27015'
  fill_in 'RCON', with: 'new-rcon'
  fill_in 'Path', with: '/home/tf2/tf2-1'
  select 'Germany'
  choose 'Yes'
end

When 'I save the server' do
  click_button 'Save'
end

When 'I update the server' do
  click_button 'Edit'
end

When 'I change the server name' do
  fill_in 'Name', with: 'New Server Name'
end

Then 'I see the new server in the list' do
  visit servers_path

  page.should have_content('This is the Server Name')
end

Then 'I see the new server name in the list' do
  visit servers_path

  page.should have_content('New Server Name')
end
