After('@logs') do
  if @reservation.id
    FileUtils.rm_rf Rails.root.join('server_logs', "#{@reservation.id}")
  end
end
