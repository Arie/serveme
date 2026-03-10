# typed: false
# frozen_string_literal: true

class StacLogsDownloader
  attr_reader :reservation

  def initialize(reservation)
    @reservation = reservation
  end

  def download_and_process
    server_stac_logs = reservation.server.stac_logs
    return unless server_stac_logs.any?

    begin
      tmp_dir = Dir.mktmpdir
      reservation.server.copy_from_server(server_stac_logs, tmp_dir)
      insert_stac_logs(tmp_dir)
      process_logs(tmp_dir)
      reservation.server.delete_from_server(server_stac_logs)
    ensure
      FileUtils.remove_entry tmp_dir
    end
  end

  private

  def insert_stac_logs(tmp_dir)
    logs = find_non_empty_logs(tmp_dir)
    return if logs.empty?

    reservation.status_update("Found #{logs.size} non-empty STAC log(s)")

    logs.each do |f|
      s = StacLog.new(reservation_id: reservation.id)
      s.filename = File.basename(f)
      s.contents = StringSanitizer.tidy_bytes(File.read(f))
      s.filesize = File.size(f)
      s.save
    end
  end

  def process_logs(tmp_dir)
    logs = find_non_empty_logs(tmp_dir)
    return if logs.empty?

    processor = StacLogProcessor.new(reservation)
    logs.each do |f|
      content = StringSanitizer.tidy_bytes(File.read(f))
      processor.process_content(content)
      save_detections(processor, content, File.basename(f))
    end
  end

  def save_detections(processor, content, filename)
    all_detections = processor.extract_detections(content)
    return if all_detections.empty?

    stac_log = reservation.stac_logs.find_by(filename: filename)

    all_detections.each_value do |data|
      detection_counts = data[:detections].tally
      detection_counts.each do |detection_type, count|
        StacDetection.create!(
          reservation: reservation,
          steam_uid: data[:steam_id64],
          player_name: data[:name],
          steam_id: data[:steam_id],
          detection_type: detection_type,
          count: count,
          stac_log: stac_log
        )
      end
    end
  end

  def find_non_empty_logs(tmp_dir)
    Dir.glob(File.join(tmp_dir, "*.log")).reject { |f| File.empty?(f) }
  end
end
