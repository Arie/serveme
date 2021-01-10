# frozen_string_literal: true

json.user do
  json.id @user.id
  json.uid @user.uid
  json.nickname @user.nickname
  json.name @user.name
  json.donator @user&.donator?
  json.donator_until @user.donator_until
  json.reservations_made @user.reservations.count
  json.total_reservation_seconds @user.total_reservation_seconds
end
