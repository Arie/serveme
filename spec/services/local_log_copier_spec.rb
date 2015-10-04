require 'spec_helper'

describe LocalLogCopier do

  describe "#copy_logs" do

    it "shells out to do the copying" do
      logs = ["foo", "bar", "b'az"]
      server = double(:logs => logs)
      reservation = double(:id => 1)
      log_copier = LocalLogCopier.new(reservation, server)
      log_copier.stub(:directory_to_copy_to => "copy_to_dir")

      log_copier.should_receive(:system).with("cp foo bar b\\'az copy_to_dir")

      log_copier.copy_logs
    end

  end

end

