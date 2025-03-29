# typed: true
# frozen_string_literal: true

class StacLogProcessor
  # Common regex patterns
  STEAM_ID_PATTERN = /StAC cached SteamID: (STEAM_\d+:\d+:\d+)/
  TIMESTAMP_PATTERN = /<.*?>/

  # Detection-specific patterns
  AIM_DETECTION_PATTERN = /\s*\[StAC\] (?:(?:Possible )?[Tt]riggerbot|SilentAim|Aimsnap) detection(?:s)? (?:of \d+\.\d+° )?on (.*?)[\.\n]/m
  CMDNUM_SPIKE_PATTERN = /\s*\[StAC\] Cmdnum SPIKE of \d+ on (.*?)\..*?Player: (.*?)<.*?\[U:1:(\d+)\].*?#{STEAM_ID_PATTERN}/m
  GENERAL_DETECTION_PATTERN = /\s*\[StAC\] \[Detection\] Player (.*?) is cheating - (.*?)!.*?#{STEAM_ID_PATTERN}/m

  # Detection type normalization
  DETECTION_TYPE_MAPPING = {
    "Possible triggerbot" => "Triggerbot"
  }.freeze

  def initialize(reservation)
    @reservation = reservation
  end

  def process_logs(tmp_dir)
    logs = find_non_empty_logs(tmp_dir)
    return if logs.empty?

    all_detections = {}

    logs.each do |log_file|
      content = File.read(log_file).force_encoding("UTF-8")
      content = content.encode("UTF-8", "UTF-8", invalid: :replace, undef: :replace, replace: "")
      process_log_content(content, all_detections)
    end

    notify_detections(all_detections) if all_detections.any?
  end

  def process_content(content)
    all_detections = {}

    # Ensure content is UTF-8 encoded
    content = content.force_encoding("UTF-8")
    content = content.encode("UTF-8", "UTF-8", invalid: :replace, undef: :replace, replace: "")

    process_log_content(content, all_detections)
    notify_detections(all_detections) if all_detections.any?
  end

  private

  def process_log_content(content, all_detections)
    detections = parse_stac_detections(content)

    detections.each_value do |data|
      steam_id64 = data[:steam_id64]
      all_detections[steam_id64] ||= {
        name: data[:name],
        steam_id: data[:steam_id],
        steam_id64: steam_id64,
        detections: []
      }

      all_detections[steam_id64][:detections].concat(data[:detections])
    end
  end

  def notify_detections(all_detections)
    StacDiscordNotifier.new(@reservation).notify(all_detections)
  end

  def find_non_empty_logs(tmp_dir)
    Dir.glob(File.join(tmp_dir, "*.log")).reject { |f| File.empty?(f) }
  end

  def parse_stac_detections(content)
    detections = {}

    parse_aim_detections(content, detections)
    parse_cmdnum_spike_detections(content, detections)
    parse_general_detections(content, detections)

    detections
  end

  def parse_aim_detections(content, detections)
    content.scan(AIM_DETECTION_PATTERN).each do |match|
      name = parse_player_name(match[0])
      next unless content =~ /#{Regexp.escape(name)}.*?#{STEAM_ID_PATTERN}/m

      steam_id = ::Regexp.last_match(1)
      steam_id64 = convert_steam_id(steam_id)

      # Get the specific detection type from the original match
      detection_type = normalize_detection_type(::Regexp.last_match(1)) if content =~ /\[StAC\] ((?:Possible )?[^d]*?) detection(?:s)? (?:of \d+\.\d+° )?on #{Regexp.escape(name)}/

      add_detection(detections, steam_id64, name, steam_id, detection_type)
    end
  end

  def parse_cmdnum_spike_detections(content, detections)
    content.scan(CMDNUM_SPIKE_PATTERN).each do |match|
      name = match[1]
      steam_id = match[3]
      steam_id64 = convert_steam_id(steam_id)

      add_detection(detections, steam_id64, name, steam_id, "CmdNum SPIKE")
    end
  end

  def parse_general_detections(content, detections)
    content.scan(GENERAL_DETECTION_PATTERN).each do |name, type, steam_id|
      name = parse_player_name(name)
      steam_id64 = convert_steam_id(steam_id)

      add_detection(detections, steam_id64, name, steam_id, type)
    end
  end

  def add_detection(detections, steam_id64, name, steam_id, type)
    detections[steam_id64] ||= {
      name: name,
      steam_id: steam_id,
      steam_id64: steam_id64,
      detections: []
    }

    detections[steam_id64][:detections] << type
  end

  def parse_player_name(name)
    name.strip.split("<").first
  end

  def convert_steam_id(steam_id)
    SteamCondenser::Community::SteamId.steam_id_to_community_id(steam_id)
  end

  def normalize_detection_type(type)
    DETECTION_TYPE_MAPPING[type] || type
  end
end
