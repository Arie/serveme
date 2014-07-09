#encoding: utf-8
#
When "I buy 1 month worth of donator status" do
  step "I go to donate"
  select "1 month - 1 EUR"
  step "I click the donate button"
end

When "I buy 1 year worth of donator status" do
  step "I go to donate"
  select "1 year - 9 EUR"
  step "I click the donate button"
end

When "I buy 1 month worth of private server" do
  step "I go to donate"
  select "Private server: 1 month - 15 EUR"
  step "I click the donate button"
end

Then "I get to choose a private server in my settings" do
  visit settings_path
  page.should have_content "Private server"

  fill_in "Private server", :with => Server.first.id
  click_button "Save private server"
end

When "I click the donate button" do
  begin
    click_button "Donate with PayPal"
  rescue ActionController::RoutingError
  end

  expect(page.status_code).to eq(302)
  expect(page.response_headers['Location']).to include('https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=EC-xxxxxxxxxx')
end

Then "my donator status lasts for a month" do
  @current_user.group_users.last.expires_at.to_date.should == 31.days.from_now.to_date
end

Then "my donator status lasts for a year" do
  @current_user.group_users.last.expires_at.to_date.should == 366.days.from_now.to_date
end

When "I go to donate" do
  click_link "Donate"
end

When "my PayPal payment was successful" do
  AnnounceDonatorWorker.should_receive(:perform_async)
  @current_user.paypal_orders.last.complete_payment!
end

Given "there are products" do
  Product.where(:name => "1 year",                  :days => 366, :price => 9.00, :currency => "EUR").first_or_create
  Product.where(:name => "1 month",                 :days => 31,  :price => 1.00, :currency => "EUR").first_or_create
  Product.where(:name => "6 months",                :days => 186, :price => 5.00, :currency => "EUR").first_or_create
  Product.where(:name => "Private server: 1 month", :days => 31,  :price => 15.00, :currency => "EUR", :grants_private_server => true).first_or_create
end
