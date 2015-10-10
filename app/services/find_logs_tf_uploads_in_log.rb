class FindLogsTfUploadsInLog

  attr_accessor :log, :logs_tf_upload_ids

  LOGS_TF_UPLOADED_REGEX = /L (?'time'.*): \[TFTrue\] The log is available here: http:\/\/logs.tf\/(?'logs_tf_id'\d+). Type !log to view it./

  def self.perform(log)
    finder = new(log)
    finder.parse_log
    finder.logs_tf_upload_ids
  end

  def initialize(log)
    @log = File.open(log)
  end

  def parse_log
    log.each_line do |line|
      logs_tf_id = find_logs_tf_upload_in_line(line)
      logs_tf_upload_ids << logs_tf_id.to_i if logs_tf_id
    end
  end

  def logs_tf_upload_ids
    @log_tf_upload_ids ||= []
  end

  def find_logs_tf_upload_in_line(line)
    begin
      match = line.match(LOGS_TF_UPLOADED_REGEX)
    rescue ArgumentError
      tidied_line = ActiveSupport::Multibyte::Chars.new(line).tidy_bytes
      match = tidied_line.match(LOGS_TF_UPLOADED_REGEX)
    end
    if match
      match[:logs_tf_id]
    end
  end

end
