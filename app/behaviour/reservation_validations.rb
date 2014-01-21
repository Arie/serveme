module ReservationValidations
  def self.included(mod)
    mod.class_eval do
      validates_presence_of :user, :server, :password, :rcon, :starts_at, :ends_at
      validates_with Reservations::UserIsAvailableValidator,                  :unless => :donator?
      validates_with Reservations::ServerIsAvailableValidator
      validates_with Reservations::ReservableByUserValidator
      validates_with Reservations::LengthOfReservationValidator
      validates_with Reservations::ChronologicalityOfTimesValidator
      validates_with Reservations::StartsNotTooFarInPastValidator,            :on => :create
      validates_with Reservations::OnlyOneFutureReservationPerUserValidator,  :unless => :donator?
      validates_with Reservations::StartsNotTooFarInFutureValidator,          :unless => :donator?
      validates_with Reservations::MapIsValidValidator
      validates_with Reservations::CustomWhitelistValidator
    end
  end
end
