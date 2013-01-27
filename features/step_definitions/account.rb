Given "I am logged in" do
  @current_user = create(:user, :uid => '12345')
  login_as(@current_user, :scope => :user)
end
