# frozen_string_literal: true

Given 'I am logged in' do
  @current_user = create(:user, uid: '12345')
  login_as(@current_user, scope: :user)
end

Given 'I am a donator' do
  @current_user.group_ids += [Group.donator_group.id]
end

Given 'I am an admin' do
  @current_user.group_ids += [Group.admin_group.id]
end

Given 'I am a streamer' do
  @current_user.group_ids += [Group.streamer_group.id]
end
