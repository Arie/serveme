# frozen_string_literal: true

json.reservation do
  json.partial! 'api/reservations/reservation', reservation: @reservation
  json.status_messages(reservation.reservation_statuses.order(:created_at).pluck(:status).map { |s| s.parameterize(separator: '_') })
end
