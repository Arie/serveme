# typed: false
# frozen_string_literal: true

require "spec_helper"

describe StockMapSource do
  let(:source) { described_class.new }

  describe ".parse_manifest" do
    let(:text) { file_fixture("depot_manifest.txt").read }

    it "returns the size and sha1 of every stock map" do
      expect(described_class.parse_manifest(text)).to eq(
        "cp_badlands" => { size: 25_981_141, sha1: "f2ae01fdc04f19d8223ca28d5011b5f691a5a99b" },
        "koth_krampus" => { size: 58_893_145, sha1: "4955e07757f55f18eea1b62ea59a09eb705c471c" }
      )
    end

    it "ignores files outside tf/maps and non-bsp files" do
      expect(described_class.parse_manifest(text).keys).not_to include("ctf_2fort", "steam.inf", "basehaptics")
    end
  end

  describe "#manifest" do
    it "parses the manifest the depot downloader wrote" do
      allow(source).to receive(:manifest_text).and_return(file_fixture("depot_manifest.txt").read)

      expect(source.manifest.keys).to contain_exactly("cp_badlands", "koth_krampus")
    end

    it "raises when the depot downloader returns no stock maps" do
      allow(source).to receive(:manifest_text).and_return("Content Manifest for Depot 232250\n")

      expect { source.manifest }.to raise_error(StockMapSource::Error, /no stock maps/i)
    end
  end

  describe "#download" do
    it "asks the depot downloader for exactly the requested maps" do
      Dir.mktmpdir do |dir|
        allow(source).to receive(:run!) { FileUtils.mkdir_p(File.join(dir, "tf", "maps")) }

        source.download([ "cp_badlands", "koth_krampus" ], dir)

        expect(File.read(File.join(dir, "filelist.txt")).split("\n")).to eq(
          [ "tf/maps/cp_badlands.bsp", "tf/maps/koth_krampus.bsp" ]
        )
      end
    end

    it "returns the path of every map the depot downloader produced" do
      Dir.mktmpdir do |dir|
        allow(source).to receive(:run!) do
          FileUtils.mkdir_p(File.join(dir, "tf", "maps"))
          File.write(File.join(dir, "tf", "maps", "cp_badlands.bsp"), "badlands")
        end

        expect(source.download([ "cp_badlands", "koth_krampus" ], dir)).to eq(
          "cp_badlands" => File.join(dir, "tf", "maps", "cp_badlands.bsp")
        )
      end
    end
  end

  describe "#run!" do
    it "kills the depot downloader when it outlives the timeout" do
      stub_const("StockMapSource::BINARY", "/bin/sleep")
      stub_const("StockMapSource::TIMEOUT", 0.2)

      expect { source.send(:run!, "30") }.to raise_error(StockMapSource::Error, /timed out/)
    end

    it "returns the output of a command that finishes in time" do
      stub_const("StockMapSource::BINARY", "/bin/echo")

      expect(source.send(:run!, "downloading")).to include("downloading")
    end
  end
end
