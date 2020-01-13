# frozen_string_literal: true

json.reservations do
  json.partial! 'api/reservations/list', reservations: @reservations
end
