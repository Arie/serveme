json.reservations do
  json.partial! 'api/reservations/list', reservations: @reservations
end
