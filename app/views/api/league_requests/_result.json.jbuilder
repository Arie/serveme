# frozen_string_literal: true

json.reservation_id result.reservation_id
json.reservation_starts_at result.reservation.starts_at
json.reservation_ends_at result.reservation.ends_at
json.steam_uid result.steam_uid
json.ip result.ip
asn = @asns[result.ip]
asn_number = asn&.respond_to?(:autonomous_system_number) ? asn.autonomous_system_number : asn&.asn_number
json.flagged_ip asn && @banned_asns[asn_number]
json.asn asn_number
json.asn_org asn&.respond_to?(:autonomous_system_organization) ? asn.autonomous_system_organization : asn&.asn_organization
json.asn_net asn&.respond_to?(:network) ? asn.network : asn&.asn_network
ip_lookup = @ip_lookups[result.ip]
json.is_proxy ip_lookup&.is_proxy || false
json.is_residential_proxy ip_lookup&.is_residential_proxy || false
json.fraud_score ip_lookup&.fraud_score
