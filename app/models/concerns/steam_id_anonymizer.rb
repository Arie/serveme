# typed: true
# frozen_string_literal: true

module SteamIdAnonymizer
  extend ActiveSupport::Concern
  extend T::Sig

  class_methods do
    extend T::Sig

    sig { params(steam_uid: T.nilable(String)).returns(T.nilable(String)) }
    def anonymize_steam_id(steam_uid)
      return nil if steam_uid.blank?

      # Use Rails key generator to create a consistent salt for this application
      # This prevents rainbow table attacks and makes it computationally infeasible
      # to reverse the hash even with knowledge of the Steam ID format
      salt = Rails.application.key_generator.generate_key("steam_id_anonymizer_salt")

      # Create a salted hash of the Steam ID
      # Using SHA256 with a secret salt makes it computationally infeasible to reverse
      Digest::SHA256.hexdigest("#{salt}#{steam_uid}")
    end
  end

  sig { params(steam_uid: T.nilable(String)).returns(T.nilable(String)) }
  def anonymize_steam_id(steam_uid)
    T.unsafe(self).class.anonymize_steam_id(steam_uid)
  end
end
