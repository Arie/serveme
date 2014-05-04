require 'spec_helper'

describe WhitelistTf do

  it { should validate_presence_of(:tf_whitelist_id) }
  it { should validate_presence_of(:content) }

  describe ".download_and_save_whitelist" do

    it "creates a whitelist if it didn't exist" do
      whitelist_content = "whitelist"
      WhitelistTf.should_receive(:whitelist_content).with(100).and_return(whitelist_content)

      WhitelistTf.download_and_save_whitelist(100)
      WhitelistTf.find_by_tf_whitelist_id(100).content.should == whitelist_content
    end

    it "updates an existing whitelist" do
      create :whitelist_tf, tf_whitelist_id: 1337, content: "old content"

      updated_content = "updated content"
      WhitelistTf.should_receive(:whitelist_content).with(1337).and_return(updated_content)
      WhitelistTf.download_and_save_whitelist(1337)

      WhitelistTf.find_by_tf_whitelist_id(1337).content.should == updated_content
    end

  end

  describe ".whitelist_content" do

    vcr_options = { :cassette_name => "whitelist_tf", :record => :new_episodes, :match_requests_on => [:method, :uri, :body] }

    it "downloads the whitelist from whitelist.tf", :vcr => vcr_options do
      WhitelistTf.whitelist_content(158).should == "the whitelist body"
    end

  end
end
