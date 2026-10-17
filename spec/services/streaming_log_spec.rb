# typed: false
# frozen_string_literal: true

require 'spec_helper'

describe StreamingLog do
  let(:tmpdir) { Pathname.new(Dir.mktmpdir('streaming_log')) }
  let(:contents) { "L 01/01/2026 - 10:00:00: World triggered \"Round_Start\"\n" * 3 }

  before { allow(described_class).to receive(:dir).and_return(tmpdir) }

  after { FileUtils.remove_entry(tmpdir) }

  let(:compress) do
    lambda do |logsecret|
      path = tmpdir.join("#{logsecret}.log")
      File.write(path, contents)
      system("zstd", "-q", "--rm", path.to_s, exception: true)
    end
  end

  describe '.readable_path' do
    it 'returns the plain log when it exists' do
      File.write(tmpdir.join('123.log'), contents)

      expect(described_class.readable_path('123')).to eq(tmpdir.join('123.log').to_s)
    end

    it 'returns the plain path when no log exists' do
      path = described_class.readable_path('123')

      expect(path).to eq(tmpdir.join('123.log').to_s)
      expect(File.exist?(path)).to be false
    end

    it 'unpacks a compressed log into the unpacked dir' do
      compress.call('123')

      path = described_class.readable_path('123')

      expect(path).to eq(tmpdir.join('unpacked', '123.log').to_s)
      expect(File.read(path)).to eq(contents)
      expect(Dir.children(tmpdir.join('unpacked'))).to eq([ '123.log' ])
    end

    it 'reuses an already unpacked log' do
      compress.call('123')
      described_class.readable_path('123')

      expect(described_class).not_to receive(:system)

      expect(File.read(described_class.readable_path('123'))).to eq(contents)
    end

    it 'falls back to the plain path when unpacking fails' do
      File.write(tmpdir.join('123.log.zst'), 'not zstd')

      path = described_class.readable_path('123')

      expect(path).to eq(tmpdir.join('123.log').to_s)
      expect(Dir.children(tmpdir.join('unpacked'))).to be_empty
    end

    it 'ignores a blank logsecret' do
      File.write(tmpdir.join('.log.zst'), 'whatever')

      expect(described_class.readable_path(nil)).to eq(tmpdir.join('.log').to_s)
    end
  end
end
