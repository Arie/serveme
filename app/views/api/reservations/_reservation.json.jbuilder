# frozen_string_literal: true

json.status reservation.status
json.starts_at reservation.starts_at
json.ends_at reservation.ends_at
json.server_id reservation.server_id
json.password reservation.password
json.rcon reservation.rcon
json.first_map reservation.first_map
json.tv_password reservation.tv_password
json.tv_relaypassword reservation.tv_relaypassword
json.server_config_id reservation.server_config_id
json.whitelist_id reservation.whitelist_id
json.custom_whitelist_id reservation.custom_whitelist_id
json.auto_end reservation.auto_end
json.enable_plugins reservation.enable_plugins
json.enable_demos_tf reservation.enable_demos_tf
json.sdr_ip reservation.sdr_ip
json.sdr_port reservation.sdr_port
json.sdr_tv_port reservation.sdr_tv_port
if reservation.persisted?
  json.id reservation.id
  json.last_number_of_players reservation.last_number_of_players
  json.inactive_minute_counter reservation.inactive_minute_counter
  json.logsecret reservation.logsecret
  json.start_instantly reservation.start_instantly
  json.end_instantly reservation.end_instantly
  json.provisioned reservation.provisioned
  json.ended reservation.ended
  json.steam_uid reservation.user.uid
  if reservation.server
    json.server do
      json.partial! 'servers/server', server: reservation.server
    end
  end
end
if reservation.ended?
  json.log_uploads reservation.log_uploads.pluck(:url)
  json.zipfile_url reservation.zipfile_url if reservation.server
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
