# frozen_string_literal: true

module ReservationValidations
  def self.included(mod)
    mod.class_eval do
      validates_presence_of :user, :password, :rcon, :starts_at, :ends_at
      validates_presence_of :server_id, unless: :gameye?
      validates :password, :tv_password, :tv_relaypassword, length: { maximum: 60 }
      validates_with Reservations::UserIsAvailableValidator,                  unless: :donator?
      validates_with Reservations::ServerIsAvailableValidator,                if: :check_server_available?
      validates_with Reservations::ReservableByUserValidator,                 if: :check_server_available?
      validates_with Reservations::LengthOfReservationValidator
      validates_with Reservations::ChronologicalityOfTimesValidator
      validates_with Reservations::StartsNotTooFarInPastValidator,            on: :create
      validates_with Reservations::OnlyOneFutureReservationPerUserValidator,  unless: :donator?
      validates_with Reservations::StartsNotTooFarInFutureValidator,          unless: :donator?
      validates_with Reservations::MapIsValidValidator
      validates_with Reservations::GameyeLocationSelectedValidator, if: :gameye?
      validates_with Reservations::CustomWhitelistValidator
      validates_with Reservations::PasswordValidator, fields: %i[password tv_password tv_relaypassword rcon]

      def check_server_available?
        times_entered? && !gameye?
      end
    end
  end
end
