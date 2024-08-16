# typed: false
# frozen_string_literal: true

Given 'I go to upload a map' do
  visit new_map_upload_path
end

When 'I try to upload a wrong kind of file' do
  bad_map = generate_fake_map('foo', 'foobar')
  attach_file('map_upload_file', bad_map.path)
  click_button 'Upload'
end

Then 'I see a message the map file was invalid' do
  page.should have_content 'not a map (bsp)'
end

When 'I try to upload an existing map' do
  file = file_fixture_upload(Rails.root.join('spec', 'fixtures', 'files', 'cp_granlands123.bsp'), 'application/octet-stream')
  _original = create :map_upload, file: file
  attach_file('map_upload_file', Rails.root.join('spec', 'fixtures', 'files', 'cp_granlands123.bsp'))
  click_button 'Upload'
end

Then 'I get shown a message I should be a donator' do
  page.should have_content 'Only donators can do that...'
end

Then 'I see a message the map is already available' do
  page.should have_content 'already available'
end

When 'I upload a new map' do
  new_map = generate_fake_map('cp_granlands2k')
  attach_file('map_upload_file', new_map.path)
  click_button('Upload')
end

Then 'I see a message that the map upload was succesful' do
  page.should have_content 'Map upload succeeded.'
end

def generate_fake_map(name, contents = 'VBSP')
  temp_file = Tempfile.new([name, '.bsp'])
  temp_file.write contents
  temp_file.close
  temp_file
end
