# typed: true
# frozen_string_literal: true

require "open3"
require "tmpdir"

# Reads stock (Valve-shipped) maps straight out of the TF2 dedicated server
# depot with DepotDownloader, so map correctness never depends on one of our
# game servers being up to date.
class StockMapSource
  extend T::Sig

  class Error < StandardError; end

  APP_ID = "232250"
  DEPOT_ID = "232250"
  BINARY = ENV.fetch("DEPOT_DOWNLOADER", "/usr/local/bin/DepotDownloader")
  TIMEOUT = 30.minutes
  # size chunks sha1 flags path, e.g. "  25981141   25 f2ae01f...  0 tf/maps/cp_badlands.bsp"
  MANIFEST_LINE = %r{^\s*(\d+)\s+\d+\s+(\h{40})\s+\d+\s+tf/maps/([^/]+)\.bsp\s*$}

  sig { params(text: String).returns(T::Hash[String, T::Hash[Symbol, T.untyped]]) }
  def self.parse_manifest(text)
    text.each_line.with_object({}) do |line, maps|
      match = line.match(MANIFEST_LINE)
      next unless match

      maps[match[3]] = { size: match[1].to_i, sha1: match[2] }
    end
  end

  sig { returns(T::Hash[String, T::Hash[Symbol, T.untyped]]) }
  def manifest
    maps = self.class.parse_manifest(manifest_text)
    raise Error, "Depot manifest listed no stock maps" if maps.empty?

    maps
  end

  sig { params(map_names: T::Array[String], directory: String).returns(T::Hash[String, String]) }
  def download(map_names, directory)
    filelist = File.join(directory, "filelist.txt")
    File.write(filelist, map_names.map { |name| "tf/maps/#{name}.bsp" }.join("\n"))
    run!("-app", APP_ID, "-depot", DEPOT_ID, "-filelist", filelist, "-dir", directory)

    map_names.filter_map do |name|
      path = File.join(directory, "tf", "maps", "#{name}.bsp")
      [ name, path ] if File.exist?(path)
    end.to_h
  end

  private

  sig { returns(String) }
  def manifest_text
    Dir.mktmpdir("depot-manifest") do |dir|
      run!("-app", APP_ID, "-depot", DEPOT_ID, "-manifest-only", "-dir", dir)
      file = Dir.glob(File.join(dir, "manifest_*.txt")).first
      raise Error, "DepotDownloader wrote no manifest" unless file

      File.read(file)
    end
  end

  sig { params(args: String).returns(String) }
  def run!(*args)
    T.unsafe(Open3).popen2e(BINARY, *args) do |stdin, out, wait_thread|
      stdin.close
      reader = Thread.new { out.read }

      unless wait_thread.join(TIMEOUT)
        Process.kill("KILL", wait_thread.pid)
        wait_thread.join
        raise Error, "#{BINARY} timed out after #{TIMEOUT}s"
      end

      output = reader.value.to_s
      raise Error, "#{BINARY} exited #{wait_thread.value.exitstatus}: #{output.last(500)}" unless wait_thread.value.success?

      output
    end
  end
end
