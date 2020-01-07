# frozen_string_literal: true

json.reservation do
  json.partial! 'api/reservations/reservation', reservation: @reservation
end
json.actions do
  json.delete api_reservation_url(@reservation)
  json.idle_reset idle_reset_api_reservation_url(@reservation)
end
