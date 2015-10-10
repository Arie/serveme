require 'spec_helper'

describe FindLogsTfUploadsInLog do

  describe ".perform" do

    it "takes a log and finds the logs.tf uploads in it" do
      log = Rails.root.join("spec", "fixtures", "logs", "special_characters.log")
      FindLogsTfUploadsInLog.perform(log).should == [1059884,1059885,1059886]
    end

  end
end

