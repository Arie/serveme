# typed: false
# frozen_string_literal: true

module SteamIdAnonymizer
  extend ActiveSupport::Concern

  class_methods do
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

  def anonymize_steam_id(steam_uid)
    self.class.anonymize_steam_id(steam_uid)
  end
end
