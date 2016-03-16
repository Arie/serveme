json.starts_at reservation.starts_at
json.ends_at reservation.ends_at
json.server_id reservation.server_id
json.password reservation.password
json.rcon reservation.rcon
json.first_map reservation.first_map
json.tv_password reservation.tv_password
json.tv_relaypassword reservation.tv_relaypassword
json.server_config_id reservation.server_config_id
json.auto_end reservation.auto_end
if reservation.persisted?
  json.id reservation.id
  json.last_number_of_players reservation.last_number_of_players
  json.inactive_minute_counter reservation.inactive_minute_counter
  json.logsecret reservation.logsecret
  json.start_instantly reservation.start_instantly
  json.end_instantly reservation.end_instantly
  json.provisioned reservation.provisioned
  json.ended reservation.ended
  json.server do
    json.partial! "servers/server", server: reservation.server
  end
end

json.errors do
  reservation.errors.to_hash.each do |attribute, errors|
    json.set! attribute do
      errors.each do |error|
        json.error error
      end
    end
  end
end
