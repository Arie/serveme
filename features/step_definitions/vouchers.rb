When "I go to activate a voucher" do
  visit new_voucher_path
end

When "I enter a valid voucher code" do
  code = Voucher.generate!(Product.find_by_name "1 month")
  fill_in_voucher_code(code)
end

When "I enter a used voucher code" do
  create(:voucher, code: "36DXQP4RBJ", claimed_at: Time.now)
  visit new_voucher_path(code: "36DXQP4RBJ")
  fill_in_voucher_code("36DXQP4RBJ")
end

Then "I see my voucher is no longer valid" do
  page.should have_content "Invalid code"
end

def fill_in_voucher_code(code)
  fill_in "Code", :with => code
  click_button "Claim"
end
