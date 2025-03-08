# typed: false
# frozen_string_literal: true

class StacLogProcessor
  def initialize(reservation)
    @reservation = reservation
  end

  def process_logs(tmp_dir)
    logs = find_non_empty_logs(tmp_dir)
    return if logs.empty?

    all_detections = {}
    demo_info = {}
    demo_timeline = {}

    logs.each do |log_file|
      content = File.read(log_file)
      process_log_content(content, all_detections, demo_info, demo_timeline)
    end

    notify_detections(all_detections, demo_info, demo_timeline) if all_detections.any?
  end

  private

  def process_log_content(content, all_detections, demo_info, demo_timeline)
    # Extract demo information
    demos = collect_demo_ticks(content)
    if demos.any?
      filename, ticks = demos.first
      demo_info[:filename] = filename
      demo_info[:tick] = ticks.last.to_s
      demo_timeline.merge!(demos)
    end

    # Process detections
    parse_stac_detections(content).each do |steam_id64, data|
      all_detections[steam_id64] ||= data.merge(detections: [])
      all_detections[steam_id64][:detections].concat(data[:detections])
    end
  end

  def notify_detections(all_detections, demo_info, demo_timeline)
    StacDiscordNotifier.new(@reservation).notify(all_detections, demo_info, demo_timeline)
  end

  def find_non_empty_logs(tmp_dir)
    Dir.glob(File.join(tmp_dir, '*.log')).reject { |f| File.empty?(f) }
  end

  def parse_stac_detections(content)
    detections = {}

    content.scan(/\s*\[StAC\] SilentAim detection.*?Player: (.*?)<.*?\[U:1:(\d+)\].*?StAC cached SteamID: STEAM_\d+:\d+:\d+/m).each do |name, steam_id3|
      steam_id64 = 76561197960265728 + steam_id3.to_i

      detections[steam_id64] ||= {
        name: name,
        steam_id64: steam_id64,
        detections: []
      }

      detections[steam_id64][:detections] << 'SilentAim'
    end

    content.scan(/\s*\[StAC\] Cmdnum SPIKE of \d+ on (.*?)\..*?Player: \1<.*?\[U:1:(\d+)\].*?StAC cached SteamID: STEAM_\d+:\d+:\d+/m).each do |name, steam_id3|
      steam_id64 = 76561197960265728 + steam_id3.to_i

      detections[steam_id64] ||= {
        name: name,
        steam_id64: steam_id64,
        detections: []
      }

      detections[steam_id64][:detections] << 'CmdNum SPIKE'
    end

    content.scan(/\s*\[StAC\] \[Detection\] Player (.*?) is cheating - (.*?)!.*?StAC cached SteamID: (STEAM_\d+:\d+:\d+)/m).each do |name, type, steam_id|
      steam_id64 = SteamCondenser::Community::SteamId.steam_id_to_community_id(steam_id)

      detections[steam_id64] ||= {
        name: name,
        steam_id64: steam_id64,
        detections: []
      }

      detections[steam_id64][:detections] << type
    end

    detections
  end

  def collect_demo_ticks(content)
    demos = {}
    content.scan(/Demo file: (.*?)\. Demo tick: (\d+)/) do |filename, tick|
      demos[filename] ||= []
      demos[filename] << tick.to_i
    end
    # Sort ticks for each demo
    demos.transform_values(&:sort)
  end
end
