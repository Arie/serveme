# frozen_string_literal: true

json.array! reservations, partial: 'api/reservations/reservation', as: :reservation
