# frozen_string_literal: true

After('@logs') do
  FileUtils.rm_rf Rails.root.join('server_logs', @reservation.id.to_s) if @reservation.id
end
