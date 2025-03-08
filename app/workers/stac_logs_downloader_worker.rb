# typed: false
# frozen_string_literal: true

class StacLogsDownloaderWorker
  attr_accessor :reservation, :reservation_id

  include Sidekiq::Worker

  def perform(reservation_id)
    @reservation_id = reservation_id
    @reservation = Reservation.find(reservation_id)

    return unless server_stac_logs.any?

    begin
      tmp_dir = Dir.mktmpdir
      reservation.server.copy_from_server(server_stac_logs, tmp_dir)
      insert_stac_logs(tmp_dir)
      process_logs(tmp_dir)
      remove_server_stac_logs
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
      s = StacLog.new(reservation_id: reservation_id)
      s.filename = File.basename(f)
      s.contents = ActiveSupport::Multibyte::Chars.new(File.read(f)).tidy_bytes.to_s
      s.filesize = File.size(f)
      s.save
    end
  end

  def process_logs(tmp_dir)
    logs = find_non_empty_logs(tmp_dir)
    return if logs.empty?

    processor = StacLogProcessor.new(reservation)
    logs.each do |f|
      processor.process_content(ActiveSupport::Multibyte::Chars.new(File.read(f)).tidy_bytes.to_s)
    end
  end

  def find_non_empty_logs(tmp_dir)
    Dir.glob(File.join(tmp_dir, '*.log')).reject { |f| File.empty?(f) }
  end

  def remove_server_stac_logs
    reservation.server.delete_from_server(server_stac_logs)
  end

  def server_stac_logs
    @server_stac_logs ||= reservation.server.stac_logs
  end
end
