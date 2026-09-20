# typed: true
# frozen_string_literal: true

require "tmpdir"

# Keeps the stock maps on fastdl identical to the current TF2 depot. Our images
# ship without maps and restore them from fastdl, so a copy left behind by an
# earlier TF2 version makes every up-to-date client fail the map CRC check.
#
# The depot manifest gives sha1 while the bucket only exposes md5 (ETag), so the
# sha1 we uploaded is recorded per map
class StockMapSync
  extend T::Sig

  SHA1_SETTING_KEY = "stock_map_sha1s"
  FASTDL_URL = "https://fastdl.serveme.tf"
  BATCH_BYTES = 2.gigabytes

  sig { params(source: StockMapSource, purger: CloudflareCachePurge).void }
  def initialize(source: StockMapSource.new, purger: CloudflareCachePurge.new)
    @source = source
    @purger = purger
    @uploaded = T.let(0, Integer)
    @verified = T.let(0, Integer)
    @failed = T.let([], T::Array[String])
    @recorded = T.let({}, T::Hash[String, String])
    @persisted = T.let({}, T::Hash[String, String])
    @changed = T.let(false, T::Boolean)
  end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def call
    manifest = @source.manifest
    objects = bucket_objects
    @recorded = recorded_sha1s
    @persisted = @recorded.dup

    adopt_uploaded_sha1s(manifest, objects)
    persist_sha1s

    outdated = manifest.select { |name, info| outdated?(info, objects["maps/#{name}.bsp"], @recorded[name]) }
    batches(outdated.keys, manifest).each { |batch| sync_batch(batch, manifest, objects) }

    refresh_map_list if @changed
    summary(manifest)
  end

  private

  sig { params(info: T::Hash[Symbol, T.untyped], object: T.nilable(T::Hash[Symbol, T.untyped]), recorded_sha1: T.nilable(String)).returns(T::Boolean) }
  def outdated?(info, object, recorded_sha1)
    return true if object.nil?
    return true if object[:size] != info[:size]

    recorded_sha1 != info[:sha1]
  end

  sig { params(manifest: T::Hash[String, T::Hash[Symbol, T.untyped]], objects: T::Hash[String, T::Hash[Symbol, T.untyped]]).void }
  def adopt_uploaded_sha1s(manifest, objects)
    adopted = manifest.select do |name, info|
      next false if @recorded[name] == info[:sha1]

      object = objects["maps/#{name}.bsp"]
      next false if object.nil? || object[:size] != info[:size]

      remote_sha1(name) == info[:sha1]
    end
    return if adopted.empty?

    @purger.purge(adopted.keys.flat_map { |name| urls_for(name) })
    adopted.each { |name, info| @recorded[name] = info[:sha1] }
    @changed = true
    persist_sha1s
  end

  sig { params(name: String).returns(T.nilable(String)) }
  def remote_sha1(name)
    ActiveStorage::Blob.service.bucket.object("maps/#{name}.bsp").metadata["valve-sha1"]
  rescue StandardError => e
    Rails.logger.info "Could not read the stored sha1 of #{name}: #{e.message}"
    nil
  end

  sig { params(names: T::Array[String], manifest: T::Hash[String, T::Hash[Symbol, T.untyped]]).returns(T::Array[T::Array[String]]) }
  def batches(names, manifest)
    bytes = 0
    names.each_with_object(T.let([], T::Array[T::Array[String]])) do |name, batches|
      size = manifest.fetch(name)[:size].to_i
      if batches.empty? || bytes + size > BATCH_BYTES
        batches << []
        bytes = 0
      end
      T.must(batches.last) << name
      bytes += size
    end
  end

  sig { params(names: T::Array[String], manifest: T::Hash[String, T::Hash[Symbol, T.untyped]], objects: T::Hash[String, T::Hash[Symbol, T.untyped]]).void }
  def sync_batch(names, manifest, objects)
    Dir.mktmpdir("stock-maps") do |directory|
      paths = @source.download(names, directory)

      names.each do |name|
        path = paths[name]
        next @failed << "#{name}: not in the depot download" if path.nil?

        sync_map(name, T.must(path), manifest.fetch(name), objects["maps/#{name}.bsp"], objects)
        File.delete(path) if File.exist?(path)
      end
    end
  end

  sig { params(name: String, path: String, info: T::Hash[Symbol, T.untyped], object: T.nilable(T::Hash[Symbol, T.untyped]), objects: T::Hash[String, T::Hash[Symbol, T.untyped]]).void }
  def sync_map(name, path, info, object, objects)
    sha1 = Digest::SHA1.file(path).hexdigest
    return @failed << "#{name}: downloaded sha1 #{sha1} does not match the depot's #{info[:sha1]}" unless sha1 == info[:sha1]

    if object && object[:md5] == Digest::MD5.file(path).hexdigest
      @verified += 1
    else
      delete_stale_bz2(name, objects)
      upload(name, path, sha1)
      @uploaded += 1
    end

    record(name, sha1)
  end

  sig { params(name: String, sha1: String).void }
  def record(name, sha1)
    return if @recorded[name] == sha1

    @purger.purge(urls_for(name))
    @recorded[name] = sha1
    @changed = true
    persist_sha1s
  end

  sig { params(name: String).returns(T::Array[String]) }
  def urls_for(name)
    [ "#{FASTDL_URL}/maps/#{name}.bsp", "#{FASTDL_URL}/maps/#{name}.bsp.bz2" ]
  end

  sig { params(name: String, path: String, sha1: String).void }
  def upload(name, path, sha1)
    File.open(path, "rb") do |file|
      ActiveStorage::Blob.service.upload(
        "maps/#{name}.bsp",
        file,
        content_type: "application/octet-stream",
        custom_metadata: { "valve-sha1" => sha1 }
      )
    end
  end

  sig { params(name: String, objects: T::Hash[String, T::Hash[Symbol, T.untyped]]).void }
  def delete_stale_bz2(name, objects)
    key = "maps/#{name}.bsp.bz2"
    return unless objects.key?(key)

    ActiveStorage::Blob.service.delete(key)
  end

  sig { returns(T::Hash[String, T::Hash[Symbol, T.untyped]]) }
  def bucket_objects
    ActiveStorage::Blob.service.bucket.objects(prefix: "maps/").each_with_object({}) do |object, objects|
      objects[object.key] = { size: object.size, md5: object.etag.to_s.delete('"') }
    end
  end

  sig { returns(T::Hash[String, String]) }
  def recorded_sha1s
    JSON.parse(SiteSetting.get(SHA1_SETTING_KEY).presence || "{}")
  rescue JSON::ParserError
    {}
  end

  sig { void }
  def persist_sha1s
    return if @recorded == @persisted

    SiteSetting.set(SHA1_SETTING_KEY, @recorded.to_json)
    @persisted = @recorded.dup
  end

  sig { void }
  def refresh_map_list
    MapUpload.refresh_bucket_objects
    AvailableMapsWorker.perform_async
  end

  sig { params(manifest: T::Hash[String, T::Hash[Symbol, T.untyped]]).returns(T::Hash[Symbol, T.untyped]) }
  def summary(manifest)
    { checked: manifest.size, uploaded: @uploaded, verified: @verified, failed: @failed }
  end
end
