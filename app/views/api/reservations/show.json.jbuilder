# frozen_string_literal: true

json.reservation do
  json.partial! 'api/reservations/reservation', reservation: @reservation
end
json.actions do
  json.patch api_reservation_url(@reservation)
  json.delete api_reservation_url(@reservation)
end
