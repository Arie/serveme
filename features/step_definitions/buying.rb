# frozen_string_literal: true

When 'I buy 1 month worth of donator status' do
  step 'I go to donate'
  select '1 month - 1 EUR'
  step 'I click the buy button'
end

When 'I buy 1 month worth of donator status with Stripe' do
  step 'I go to donate'
  click_button 'Credit Card'
  fill_in 'card-number', with: '4242 4242 4242 4242'
  fill_in 'expiry', with: '10/18'
  fill_in 'cvc', with: '123'
  select '1 month - 1 EUR'
  step 'I click the buy button'
end

When 'I buy 1 year worth of donator status' do
  step 'I go to donate'
  select '1 year - 9 EUR'
  step 'I click the buy button'
end

When 'I buy 1 month worth of private server' do
  step 'I go to donate'
  select 'Private server: 1 month - 15 EUR'
  step 'I click the buy button'
end

When 'I buy 1 month worth of donator status for someone else' do
  step 'I go to donate'
  select '1 month - 1 EUR'
  choose 'Gift, receive a sharable premium code'
  step 'I click the buy button'
end

Then 'I see a premium code on my settings page' do
  visit settings_path
  page.should have_content 'Your premium codes'
end

Then 'I get to choose a private server in my settings' do
  server = create(:server)
  visit settings_path
  page.should have_content 'Private server'

  fill_in 'Private server', with: server.id
  click_button 'Save private server'
end

When 'I click the buy button' do
  begin
    page.find('button.submit').click
  rescue ActionController::RoutingError
  end

  expect(page.status_code).to eq(302)
  expect(page.response_headers['Location']).to include('https://www.sandbox.paypal.com/cgi-bin/webscr?cmd=_express-checkout&token=EC-xxxxxxxxxx')
end

Then 'my donator status lasts for a month' do
  @current_user.group_users.last.expires_at.to_date.should == 31.days.from_now.to_date
end

Then 'my donator status lasts for a year' do
  @current_user.group_users.last.expires_at.to_date.should == 366.days.from_now.to_date
end

When 'I go to donate' do
  visit new_order_path
end

When 'my PayPal payment was successful' do
  AnnounceDonatorWorker.should_receive(:perform_async)
  @current_user.paypal_orders.last.handle_successful_payment!
end

Given 'there are products' do
  Product.where(name: '1 year',                  days: 366, price: 9.00, currency: 'EUR').first_or_create
  Product.where(name: '1 month',                 days: 31,  price: 1.00, currency: 'EUR').first_or_create
  Product.where(name: '6 months',                days: 186, price: 5.00, currency: 'EUR').first_or_create
  Product.where(name: 'Private server: 1 month', days: 31,  price: 15.00, currency: 'EUR', grants_private_server: true).first_or_create
end
