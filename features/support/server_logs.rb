After('@logs') do
  if @reservation.id
    FileUtils.rmdir Rails.root.join('server_logs', "#{@reservation.id}")
  end
end
