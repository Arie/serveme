# frozen_string_literal: true

json.reservation_id result.reservation_id
json.reservation_starts_at result.reservation.starts_at
json.reservation_ends_at result.reservation.ends_at
json.steam_uid result.steam_uid
json.ip result.ip
json.flagged_ip @flagged_ips[result.ip] == true
