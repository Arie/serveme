# typed: false
# frozen_string_literal: true

require "spec_helper"

describe CloudImageBuildOutputStreamer do
  let(:build) { CloudImageBuild.create!(version: "1234") }
  let(:streamer) { described_class.new(build) }

  before do
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
  end

  describe "#append + #flush!" do
    it "appends buffered output to the build on flush" do
      streamer.append("line one\n")
      streamer.append("line two\n")
      streamer.flush!

      expect(build.reload.output).to eq("line one\nline two\n")
    end

    it "broadcasts the buffered chunk to the build's output stream" do
      streamer.append("hello\n")
      streamer.flush!

      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with(
        [ build, "output" ],
        hash_including(target: "build-output", html: "hello\n")
      )
    end

    it "html-escapes broadcast content" do
      streamer.append("<script>alert(1)</script>\n")
      streamer.flush!

      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with(
        [ build, "output" ],
        hash_including(html: "&lt;script&gt;alert(1)&lt;/script&gt;\n")
      )
    end

    it "is a no-op when buffer is empty" do
      streamer.flush!
      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_append_to)
      expect(build.reload.output).to eq("")
    end
  end

  describe "auto-flush thresholds" do
    it "auto-flushes after FLUSH_LINES lines" do
      described_class::FLUSH_LINES.times { |i| streamer.append("line #{i}\n") }
      expect(build.reload.output.lines.size).to eq(described_class::FLUSH_LINES)
    end

    it "does not auto-flush below FLUSH_LINES lines" do
      (described_class::FLUSH_LINES - 1).times { |i| streamer.append("line #{i}\n") }
      expect(build.reload.output).to eq("")
    end
  end

  describe "tail-cap" do
    let(:cap) { described_class::MAX_BYTES }

    it "truncates earlier output when over cap, prepending a marker" do
      build.update!(output: "a" * (cap - 100))
      streamer.append("b" * 200) # combined exceeds cap
      streamer.flush!

      reloaded = build.reload.output
      expect(reloaded.bytesize).to be <= cap
      expect(reloaded).to start_with(described_class::TRUNCATION_MARKER)
      expect(reloaded).to end_with("b" * 200)
    end

    it "leaves output untouched when under cap" do
      build.update!(output: "a" * 100)
      streamer.append("b" * 100)
      streamer.flush!

      expect(build.reload.output).to eq(("a" * 100) + ("b" * 100))
    end
  end
end
