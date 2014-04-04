Given "I go to upload a map" do
  visit new_map_upload_path
end

When "I try to upload a wrong kind of file" do
  bad_map = generate_fake_map('foo', 'foobar')
  attach_file('map_upload_file', bad_map.path)
  click_button "Upload"
end

Then "I see a message the map file was invalid" do
  page.should have_content "not a map (bsp)"
end

When "I try to upload an existing map" do
  UploadFilesToServersWorker.should_receive(:perform_async)
  original = create :map_upload
  attach_file("map_upload_file", original.file.path)
  click_button "Upload"
end

Then "I get shown a message I should be a donator" do
  page.should have_content "Only donators can do that..."
end

Then "I see a message the map is already available" do
  page.should have_content "already available"
end

When "I upload a new map" do
  UploadFilesToServersWorker.should_receive(:perform_async)
  new_map = generate_fake_map("cp_granlands2k")
  attach_file("map_upload_file", new_map.path)
  click_button("Upload")
end

Then "I see a message that the map upload was succesful" do
  page.should have_content "Map upload succeeded, it can take a few minute for it to get synced to all servers"
end

def generate_fake_map(name, contents = "VBSP")
  temp_file = Tempfile.new([name, '.bsp'])
  temp_file.write contents
  temp_file.close
  temp_file
end
