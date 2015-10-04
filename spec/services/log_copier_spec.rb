require 'spec_helper'

describe LogCopier do

  describe ".copy" do

    it "logs and error and instantiates the right kind of log copier" do
      dummy_log_copier_class = double(:dummy_log_copier_class)
      dummy_log_copier = double(:dummy_log_copier)
      reservation = double(:reservation)
      server      = double(:server, log_copier_class: dummy_log_copier_class)

      reservation.should_receive(:status_update)
      dummy_log_copier_class.should_receive(:new).with(reservation, server).and_return(dummy_log_copier)
      dummy_log_copier.should_receive(:copy)

      LogCopier.copy(reservation, server)
    end

  end

  context "instance" do

    let(:logs)        { double(:logs) }
    let(:server)      { double(:server, logs: logs) }
    let(:reservation) { double(:reservation) }
    let(:log_copier)  { LogCopier.new(reservation, server) }

    describe "#copy" do

      it "makes the directory, sets the permissions and copies the logs" do
        log_copier.should_receive(:make_directory)
        log_copier.should_receive(:set_directory_permissions)
        log_copier.should_receive(:copy_logs)

        log_copier.copy
      end

    end

    describe "#make_directory" do
      it "creats the directory to copy to" do
        directory_to_copy_to = double(:directory_to_copy_to)
        log_copier.stub(:directory_to_copy_to => directory_to_copy_to)
        FileUtils.should_receive(:mkdir_p).with(directory_to_copy_to)
        log_copier.make_directory
      end
    end

    describe "#directory_to_copy_to" do

      it "generates a directory path based on reservation id "do
        reservation.stub(:id => "12345")
        root = double(:root)
        root.should_receive(:join).with("server_logs", "12345")
        Rails.stub(:root => root)

        log_copier.directory_to_copy_to
      end
    end

    describe "#set_directory_permissions" do

      it "sets the permissions so they can be presented through a web server" do
        directory_to_copy_to = double(:directory_to_copy_to)
        log_copier.stub(:directory_to_copy_to => directory_to_copy_to)
        FileUtils.should_receive(:chmod_R).with(0775, directory_to_copy_to)

        log_copier.set_directory_permissions
      end
    end

  end

end

