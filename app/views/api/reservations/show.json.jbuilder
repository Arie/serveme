json.reservation do
  json.partial! 'api/reservations/reservation', reservation: @reservation
end
json.actions do
  json.delete api_reservation_url(@reservation)
end
