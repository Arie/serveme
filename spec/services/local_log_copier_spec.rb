# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe LocalLogCopier do
  describe '#copy_logs' do
    it 'uses Open3.capture3 to strip IPs and copy logs' do
      logs = [ 'foo', 'bar', "b'az" ]
      server = double(logs: logs)
      reservation = double(id: 1)
      log_copier = LocalLogCopier.new(reservation, server)
      log_copier.stub(directory_to_copy_to: 'copy_to_dir')

      expect(Open3).to receive(:capture3).with("LANG=ALL", "LC_ALL=C", "sed", "-i", "-r", "s/(\\b[0-9]{1,3}\\.){3}[0-9]{1,3}\\b/0.0.0.0/g", "foo", "bar", "b'az").and_return([ "", "", double(success?: true) ])
      expect(Open3).to receive(:capture3).with("cp", "foo", "bar", "b'az", "copy_to_dir").and_return([ "", "", double(success?: true) ])

      log_copier.copy_logs
    end
  end
end
