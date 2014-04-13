json.reservation do
  json.partial! 'api/reservations/reservation', reservation: @reservation
  json.actions do
    json.delete api_reservation_url(@reservation)
  end
end
