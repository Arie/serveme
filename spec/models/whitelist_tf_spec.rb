require 'spec_helper'

describe WhitelistTf do

  it { should validate_presence_of(:tf_whitelist_id) }
  it { should validate_presence_of(:content) }

  describe ".find_or_download" do

    it "find an existing whitelist" do
      whitelist = double
      WhitelistTf.should_receive(:find_by_tf_whitelist_id).with(100).and_return(whitelist)

      WhitelistTf.find_or_download(100).should == whitelist
    end

    it "downloads a whitelist if it didn't exist" do
      whitelist = double
      WhitelistTf.should_receive(:find_by_tf_whitelist_id).with(100).and_return(nil)
      WhitelistTf.should_receive(:download_and_save_whitelist).with(100).and_return(whitelist)

      WhitelistTf.find_or_download(100).should == whitelist
    end

  end

  describe ".whitelist_content" do

    vcr_options = { :cassette_name => "whitelist_tf", :record => :new_episodes, :match_requests_on => [:method, :uri, :body] }

    it "downloads the whitelist from whitelist.tf", :vcr => vcr_options do
      WhitelistTf.whitelist_content(158).should == "the whitelist body"
    end

  end
end
