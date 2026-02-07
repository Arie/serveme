# typed: false
# frozen_string_literal: true

require 'spec_helper'
require 'safe_file_deletion'

describe SafeFileDeletion do
  describe '.validate_temp_directory!' do
    context 'with valid paths' do
      it 'accepts paths matching /tmp/reservation-{digits}' do
        expect { described_class.validate_temp_directory!('/tmp/reservation-123') }.not_to raise_error
        expect { described_class.validate_temp_directory!('/tmp/reservation-999999') }.not_to raise_error
      end

      it 'accepts paths matching /tmp/temp_dir_{digits}' do
        expect { described_class.validate_temp_directory!('/tmp/temp_dir_12345') }.not_to raise_error
        expect { described_class.validate_temp_directory!('/tmp/temp_dir_98765') }.not_to raise_error
      end

      it 'accepts paths matching {any}/tf/temp_reservation_{digits}' do
        expect { described_class.validate_temp_directory!('/home/tf2server/server/tf/temp_reservation_456') }.not_to raise_error
        expect { described_class.validate_temp_directory!('/opt/servers/gameserver/tf/temp_reservation_789') }.not_to raise_error
      end
    end

    context 'with invalid paths' do
      it 'rejects nil or empty paths' do
        expect { described_class.validate_temp_directory!(nil) }.to raise_error(SafeFileDeletion::InvalidPathError, /cannot be nil/)
        expect { described_class.validate_temp_directory!('') }.to raise_error(SafeFileDeletion::InvalidPathError, /cannot be nil/)
      end

      it 'rejects system directories (not in allowlist)' do
        expect { described_class.validate_temp_directory!('/') }.to raise_error(SafeFileDeletion::InvalidPathError)
        expect { described_class.validate_temp_directory!('/home') }.to raise_error(SafeFileDeletion::InvalidPathError)
        expect { described_class.validate_temp_directory!('/usr/local') }.to raise_error(SafeFileDeletion::InvalidPathError)
        expect { described_class.validate_temp_directory!('/etc/config') }.to raise_error(SafeFileDeletion::InvalidPathError)
        expect { described_class.validate_temp_directory!('/var/log') }.to raise_error(SafeFileDeletion::InvalidPathError)
      end

      it 'rejects paths that do not match allowed patterns' do
        expect { described_class.validate_temp_directory!('/tmp/something-else') }.to raise_error(SafeFileDeletion::InvalidPathError, /does not match allowed/)
        expect { described_class.validate_temp_directory!('/tmp/reservation_123') }.to raise_error(SafeFileDeletion::InvalidPathError, /does not match allowed/)
        expect { described_class.validate_temp_directory!('/var/tmp/reservation-123') }.to raise_error(SafeFileDeletion::InvalidPathError, /does not match allowed/)
        expect { described_class.validate_temp_directory!('/tmp/reservations/123') }.to raise_error(SafeFileDeletion::InvalidPathError, /does not match allowed/)
      end

      it 'rejects paths without temp or tmp keyword' do
        expect { described_class.validate_temp_directory!('/home/user/reservation-123') }.to raise_error(SafeFileDeletion::InvalidPathError)
      end

      it 'expands and rejects relative path traversal attempts' do
        expect { described_class.validate_temp_directory!('../../../etc') }.to raise_error(SafeFileDeletion::InvalidPathError)
        expect { described_class.validate_temp_directory!('../../tmp/reservation-123') }.to raise_error(SafeFileDeletion::InvalidPathError)
      end

      it 'rejects paths with correct format but wrong location' do
        # Looks like a reservation path but not in /tmp
        expect { described_class.validate_temp_directory!('/home/reservation-123') }.to raise_error(SafeFileDeletion::InvalidPathError)
        expect { described_class.validate_temp_directory!('/opt/temp_dir_123') }.to raise_error(SafeFileDeletion::InvalidPathError)
      end

      it 'rejects user home directories even with temp in name' do
        expect { described_class.validate_temp_directory!('/home/user/temp') }.to raise_error(SafeFileDeletion::InvalidPathError)
        expect { described_class.validate_temp_directory!('/root/tmp') }.to raise_error(SafeFileDeletion::InvalidPathError)
      end
    end
  end

  describe '.safe_remove_directory' do
    let(:temp_dir) { '/tmp/reservation-999' }

    before do
      # Allow the validation to pass
      allow(described_class).to receive(:validate_temp_directory!)
    end

    it 'returns false if directory does not exist' do
      allow(File).to receive(:exist?).with(temp_dir).and_return(false)
      expect(described_class.safe_remove_directory(temp_dir)).to be false
    end

    it 'returns false if path is not a directory' do
      allow(File).to receive(:exist?).with(temp_dir).and_return(true)
      allow(File).to receive(:directory?).with(temp_dir).and_return(false)
      expect(described_class.safe_remove_directory(temp_dir)).to be false
    end

    it 'removes directory and returns true on success' do
      allow(File).to receive(:exist?).with(temp_dir).and_return(true)
      allow(File).to receive(:directory?).with(temp_dir).and_return(true)
      allow(Dir).to receive(:entries).with(temp_dir).and_return([ '.', '..', 'file.log', 'demo.dem' ])

      expect(FileUtils).to receive(:rm_rf).with(temp_dir)
      expect(Rails.logger).to receive(:info).with(/Successfully removed/)

      expect(described_class.safe_remove_directory(temp_dir)).to be true
    end

    it 'catches and logs errors during deletion' do
      allow(File).to receive(:exist?).with(temp_dir).and_return(true)
      allow(File).to receive(:directory?).with(temp_dir).and_return(true)
      allow(Dir).to receive(:entries).with(temp_dir).and_return([ '.', '..' ])
      allow(FileUtils).to receive(:rm_rf).and_raise(StandardError.new("Permission denied"))

      expect(Rails.logger).to receive(:error).with(/Error removing/)

      expect(described_class.safe_remove_directory(temp_dir)).to be false
    end
  end

  describe '.safe_remove_directory!' do
    let(:temp_dir) { '/tmp/reservation-888' }

    before do
      allow(described_class).to receive(:validate_temp_directory!)
    end

    it 'raises error if path does not exist' do
      allow(File).to receive(:exist?).with(temp_dir).and_return(false)
      expect(Rails.logger).to receive(:warn).with(/does not exist/)
      expect(described_class.safe_remove_directory!(temp_dir)).to be false
    end

    it 'raises error if path is not a directory' do
      allow(File).to receive(:exist?).with(temp_dir).and_return(true)
      allow(File).to receive(:directory?).with(temp_dir).and_return(false)

      expect { described_class.safe_remove_directory!(temp_dir) }.to raise_error(SafeFileDeletion::InvalidPathError, /not a directory/)
    end

    it 'removes directory successfully' do
      allow(File).to receive(:exist?).with(temp_dir).and_return(true)
      allow(File).to receive(:directory?).with(temp_dir).and_return(true)

      expect(FileUtils).to receive(:rm_rf).with(temp_dir)
      expect(Rails.logger).to receive(:info).with(/Successfully removed/)

      expect(described_class.safe_remove_directory!(temp_dir)).to be true
    end

    it 'logs and re-raises errors' do
      allow(File).to receive(:exist?).with(temp_dir).and_return(true)
      allow(File).to receive(:directory?).with(temp_dir).and_return(true)
      allow(FileUtils).to receive(:rm_rf).and_raise(StandardError.new("Disk full"))

      expect(Rails.logger).to receive(:error).with(/Error removing/)

      expect { described_class.safe_remove_directory!(temp_dir) }.to raise_error(StandardError, "Disk full")
    end
  end
end
