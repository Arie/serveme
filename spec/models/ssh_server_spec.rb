require 'spec_helper'

describe SshServer do

  describe '#remove_configuration' do

    it 'deletes the reservation.cfg if its available' do
    end

    it 'does not explode when there is no reservation.cfg' do
    end

  end

  describe '#restart' do

    it "sends the software termination signal to the process" do
    end

    it "logs an error when it couldn't find the process id" do
    end

  end

  describe '#find_process_id' do

    it 'picks the correct pid from the list' do
    end

  end

  describe '#demos' do

    it 'finds the demo files' do
    end

  end

  describe '#logs' do

    it 'finds the log files' do
    end

  end

  describe '#remove_logs_and_demos' do

    it 'removes the logs and demos' do
    end

  end

  describe '#update_configuration' do

    it 'writes the configuration file' do
    end

  end

end
