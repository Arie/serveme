# typed: false
# frozen_string_literal: true

require "spec_helper"

describe StockMapSync do
  let(:contents) { { "cp_badlands" => "badlands bsp", "koth_krampus" => "krampus bsp" } }
  let(:downloads) { contents }
  let(:manifest) do
    contents.transform_values { |content| { size: content.bytesize, sha1: Digest::SHA1.hexdigest(content) } }
  end
  let(:repacked_content) { "badlands bsp, repacked by Valve" }
  let(:repacked_manifest) do
    manifest.merge("cp_badlands" => { size: repacked_content.bytesize, sha1: Digest::SHA1.hexdigest(repacked_content) })
  end
  let(:source) { instance_double(StockMapSource, manifest: manifest) }
  let(:service) { instance_double(ActiveStorage::Service::S3Service) }
  let(:bucket) { double("bucket") }
  let(:bucket_contents) { [] }
  let(:purger) { instance_double(CloudflareCachePurge, purge: nil) }
  let(:sync) { described_class.new(source: source, purger: purger) }

  define_method(:bucket_object) do |key, size, md5|
    instance_double(Aws::S3::ObjectSummary, key: key, size: size, etag: "\"#{md5}\"")
  end

  define_method(:map_object) do |name|
    content = contents.fetch(name)
    bucket_object("maps/#{name}.bsp", content.bytesize, Digest::MD5.hexdigest(content))
  end

  define_method(:recorded_sha1s) do
    JSON.parse(SiteSetting.get(described_class::SHA1_SETTING_KEY).presence || "null")
  end

  define_method(:urls_for) do |name|
    [ "https://fastdl.serveme.tf/maps/#{name}.bsp", "https://fastdl.serveme.tf/maps/#{name}.bsp.bz2" ]
  end

  before do
    allow(ActiveStorage::Blob).to receive(:service).and_return(service)
    allow(service).to receive(:bucket).and_return(bucket)
    allow(service).to receive(:upload)
    allow(service).to receive(:delete)
    allow(bucket).to receive(:objects).with(prefix: "maps/").and_return(bucket_contents)
    allow(bucket).to receive(:object).and_return(double("object", metadata: {}))
    allow(MapUpload).to receive(:refresh_bucket_objects)
    allow(AvailableMapsWorker).to receive(:perform_async)
    allow(source).to receive(:download) do |names, dir|
      names.to_h do |name|
        path = File.join(dir, "#{name}.bsp")
        File.write(path, downloads.fetch(name))
        [ name, path ]
      end
    end
  end

  describe "#call" do
    it "uploads a stock map that is missing from the bucket" do
      sync.call

      expect(service).to have_received(:upload).with(
        "maps/cp_badlands.bsp", anything, hash_including(custom_metadata: { "valve-sha1" => manifest["cp_badlands"][:sha1] })
      )
    end

    it "records the sha1 of every map it synced" do
      sync.call

      expect(recorded_sha1s).to eq(
        "cp_badlands" => manifest["cp_badlands"][:sha1],
        "koth_krampus" => manifest["koth_krampus"][:sha1]
      )
    end

    it "purges the edge cache of every map it replaced" do
      sync.call

      expect(purger).to have_received(:purge).with(urls_for("cp_badlands"))
      expect(purger).to have_received(:purge).with(urls_for("koth_krampus"))
    end

    it "purges the bz2 url of a replaced map even when this run saw no bz2 to delete" do
      sync.call

      expect(purger).to have_received(:purge).with(array_including("https://fastdl.serveme.tf/maps/cp_badlands.bsp.bz2"))
    end

    it "refreshes the map list once maps changed" do
      sync.call

      expect(MapUpload).to have_received(:refresh_bucket_objects)
      expect(AvailableMapsWorker).to have_received(:perform_async)
    end

    context "when the bucket already holds the current version" do
      let(:bucket_contents) { [ map_object("cp_badlands"), map_object("koth_krampus") ] }

      it "records the sha1 without uploading anything" do
        sync.call

        expect(service).not_to have_received(:upload)
        expect(recorded_sha1s.keys).to contain_exactly("cp_badlands", "koth_krampus")
      end
    end

    context "when a map's sha1 was recorded on an earlier run" do
      let(:bucket_contents) { [ map_object("cp_badlands"), map_object("koth_krampus") ] }

      before do
        SiteSetting.set(described_class::SHA1_SETTING_KEY, manifest.transform_values { |info| info[:sha1] }.to_json)
      end

      it "downloads nothing at all" do
        sync.call

        expect(source).not_to have_received(:download)
      end

      it "leaves the map list caches alone" do
        sync.call

        expect(MapUpload).not_to have_received(:refresh_bucket_objects)
        expect(purger).not_to have_received(:purge)
      end

      it "downloads the map again when the bucket copy changed size behind our back" do
        allow(bucket).to receive(:objects).with(prefix: "maps/").and_return(
          [ bucket_object("maps/cp_badlands.bsp", 1, "0" * 32), map_object("koth_krampus") ]
        )

        sync.call

        expect(source).to have_received(:download).with([ "cp_badlands" ], anything)
      end

      context "and Valve repacked it" do
        let(:downloads) { contents.merge("cp_badlands" => repacked_content) }

        before { allow(source).to receive(:manifest).and_return(repacked_manifest) }

        it "downloads the map again" do
          sync.call

          expect(source).to have_received(:download).with([ "cp_badlands" ], anything)
        end

        it "records the new sha1, so the next run skips it again" do
          sync.call

          expect(recorded_sha1s["cp_badlands"]).to eq(Digest::SHA1.hexdigest(repacked_content))
        end
      end
    end

    context "when the bucket copy carries the sha1 we uploaded" do
      let(:bucket_contents) do
        [ bucket_object("maps/cp_badlands.bsp", contents["cp_badlands"].bytesize, "#{'0' * 32}-3"), map_object("koth_krampus") ]
      end

      before do
        allow(bucket).to receive(:object).with("maps/cp_badlands.bsp").and_return(
          double("object", metadata: { "valve-sha1" => manifest["cp_badlands"][:sha1] })
        )
      end

      it "adopts that sha1 instead of downloading a map its multipart ETag cannot vouch for" do
        sync.call

        expect(source).not_to have_received(:download).with(array_including("cp_badlands"), anything)
        expect(service).not_to have_received(:upload)
      end

      it "purges it anyway, because the run that uploaded it may have died before purging" do
        sync.call

        expect(purger).to have_received(:purge).with(array_including(*urls_for("cp_badlands")))
      end

      it "refreshes the map list, because an adopted map may be one this region never listed" do
        sync.call

        expect(MapUpload).to have_received(:refresh_bucket_objects)
      end
    end

    context "when the bucket copy matches but was never recorded" do
      let(:bucket_contents) { [ map_object("cp_badlands"), map_object("koth_krampus") ] }

      it "purges it, since an earlier run may have uploaded it and failed to purge" do
        sync.call

        expect(purger).to have_received(:purge).with(urls_for("cp_badlands"))
      end
    end

    context "when a downloaded map does not match the manifest" do
      let(:downloads) { contents.transform_values { "corrupted" } }

      it "does not upload it" do
        sync.call

        expect(service).not_to have_received(:upload)
      end

      it "reports it as failed and does not record a sha1 for it" do
        expect(sync.call[:failed]).to include(a_string_matching(/cp_badlands/))
        expect(recorded_sha1s).to be_nil
      end
    end

    context "when a stale compressed copy sits next to the map" do
      let(:bucket_contents) { [ bucket_object("maps/cp_badlands.bsp", 1, "0" * 32), bucket_object("maps/cp_badlands.bsp.bz2", 1, "0" * 32) ] }

      it "deletes the bz2 so clients cannot keep downloading the old map" do
        sync.call

        expect(service).to have_received(:delete).with("maps/cp_badlands.bsp.bz2")
      end

      it "purges the bz2 url too" do
        sync.call

        expect(purger).to have_received(:purge).with(array_including("https://fastdl.serveme.tf/maps/cp_badlands.bsp.bz2"))
      end
    end

    context "when an upload fails halfway through" do
      let(:bucket_contents) { [ bucket_object("maps/cp_badlands.bsp.bz2", 1, "0" * 32) ] }

      before do
        allow(service).to receive(:upload).with("maps/koth_krampus.bsp", anything, anything).and_raise("R2 is down")
      end

      it "keeps the sha1 of the maps it already synced" do
        expect { sync.call }.to raise_error("R2 is down")

        expect(recorded_sha1s.keys).to eq([ "cp_badlands" ])
      end

      it "has already deleted the stale bz2 of the map it was replacing" do
        allow(service).to receive(:upload).and_raise("R2 is down")

        expect { sync.call }.to raise_error("R2 is down")
        expect(service).to have_received(:delete).with("maps/cp_badlands.bsp.bz2")
      end
    end

    context "when the maps do not fit in one download" do
      it "splits them into batches bounded by total bytes" do
        stub_const("#{described_class}::BATCH_BYTES", contents["cp_badlands"].bytesize)

        sync.call

        expect(source).to have_received(:download).with([ "cp_badlands" ], anything)
        expect(source).to have_received(:download).with([ "koth_krampus" ], anything)
      end
    end
  end
end
