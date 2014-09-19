Given "there is a rating" do
  create :rating, :user => create(:user)
end

Given "there is a published rating" do
  create :rating, :published => true
end

When "I go to the ratings" do
  visit ratings_path
end

When "I publish a rating" do
  click_link "Publish"
end

When "I unpublish a rating" do
  click_link "Unpublish"
end

When "I destroy the rating" do
  click_link "Destroy"
end

Then "I can't see the rating" do
  page.should_not have_content "aimaaiizing"
end

Then "I see the rating is published" do
  page.should have_content "Unpublish"
end

Then "I see the rating is unpublished" do
  page.should_not have_content "Unpublish"
end
