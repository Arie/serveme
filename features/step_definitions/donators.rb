# typed: false
# frozen_string_literal: true

Given 'I am on the donators page' do
  visit admin_users_path(group_id: Group.donator_group.id)
end

Given 'there is a donator' do
  @donator = create :user, nickname: 'Donator'
  GroupUser.create(expires_at: 1.month.from_now,
                   group_id: Group.donator_group.id,
                   user_id: @donator.id)
end

When 'I go add a donator' do
  visit new_admin_user_path
end

When 'I edit the donator' do
  visit edit_admin_user_path(@donator)
end

When 'I change the expiration date' do
  click_button 'Update Expiry'
  within "#updateExpiryModal#{@donator.group_users.first.id}" do
    fill_in 'expires_at', with: '2100-10-10T10:10'
    click_button 'Update'
  end
end

Then 'I can see the new expiration date' do
  page.should have_content '2100-10-10 10:10'
end

Given 'there is a non-donator' do
  create :user, uid: '1122334455', nickname: 'Future donator'
end

When 'I enter his uid' do
  fill_in 'Find User', with: '1122334455'
end

When 'I save the donator' do
  click_button 'Save'
end

Then 'I see the new donator in the list' do
  page.should have_content 'Future donator'
end
