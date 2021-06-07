# frozen_string_literal: true

When 'I go to activate a premium code' do
  visit new_voucher_path
end

When 'I enter a valid premium code' do
  voucher = Voucher.generate!(Product.find_by_name('1 month'))
  fill_in_voucher_code(voucher.code)
end

When 'I enter a used premium code' do
  create(:voucher, code: '36DXQP4RBJ', claimed_at: Time.now)
  visit new_voucher_path(code: '36DXQP4RBJ')
  fill_in_voucher_code('36DXQP4RBJ')
end

Then 'I see my premium code is no longer valid' do
  page.should have_content 'Invalid code'
end

def fill_in_voucher_code(code)
  fill_in 'Code', with: code
  click_button 'Claim'
end
