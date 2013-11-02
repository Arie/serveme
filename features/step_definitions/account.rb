Given "I am logged in" do
  @current_user = create(:user, :uid => '12345')
  login_as(@current_user, :scope => :user)
end

Given "I am a donator" do
  @current_user.groups << Group.donator_group
end
