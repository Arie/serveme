Given "I am on the donators page" do
  visit donators_path
end

Given "there is a donator" do
  @donator = create :user, nickname: "Donator"
  GroupUser.create(expires_at: 1.month.from_now,
                   group_id: Group.donator_group.id,
                   user_id: @donator.id)
end

When "I go add a donator" do
  visit new_donator_path
end

When "I edit the donator" do
  visit edit_donator_path(@donator)
end

When "I change the expiration date" do
  fill_in "Expires at", :with => "10-10-2020 10:10"
  click_button "Update"
end

Then "I can see the new expiration date" do
  within "tr#user_#{@donator.id}" do
    page.should have_content "2020-10-10 10:10"
  end
end

Given "there is a non-donator" do
  create :user, uid: "1122334455", nickname: "Future donator"
end

When "I enter his uid" do
  fill_in "User", with: "1122334455"
end

When "I save the donator" do
  click_button "Save"
end

Then "I see the new donator in the list" do
  page.should have_content "Future donator"
end
