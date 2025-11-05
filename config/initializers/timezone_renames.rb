# typed: false
# frozen_string_literal: true

# Fix for IANA timezone renames that Rails' MAPPING doesn't handle
# See: https://github.com/rails/rails/issues/44273
# See: https://github.com/rails/rails/pull/51703
#
# On Debian Trixie and other modern systems, the old timezone names (Europe/Kiev,
# America/Godthab, Asia/Rangoon) no longer exist in the system tzdata, causing them
# to be excluded from ActiveSupport::TimeZone.all even though the new names exist.
#
# This initializer updates Rails' MAPPING to use whichever variant exists on the system.

Rails.application.config.after_initialize do
  renamed_timezones = {
    "Kyiv" => [ "Europe/Kyiv", "Europe/Kiev" ],           # Renamed in tzdata 2022b
    "Greenland" => [ "America/Nuuk", "America/Godthab" ],  # Renamed
    "Rangoon" => [ "Asia/Yangon", "Asia/Rangoon" ]         # Renamed
  }

  renamed_timezones.each do |name, identifiers|
    available = identifiers.find { |id| ActiveSupport::TimeZone[id] }

    if available && ActiveSupport::TimeZone::MAPPING[name] != available
      ActiveSupport::TimeZone::MAPPING[name] = available
      Rails.logger.debug "Updated timezone MAPPING: #{name} => #{available}"
    end
  end

  ActiveSupport::TimeZone.clear
end
