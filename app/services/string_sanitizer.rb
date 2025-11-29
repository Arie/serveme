# typed: strict
# frozen_string_literal: true

# Service to sanitize strings by handling invalid UTF-8 bytes.
# Replaces the deprecated ActiveSupport::Multibyte::Chars#tidy_bytes.
# Implementation based on Rails' ActiveSupport::Multibyte::Unicode#tidy_bytes
module StringSanitizer
  extend T::Sig

  # Sanitizes a string by removing or replacing invalid UTF-8 bytes.
  # This is a replacement for the deprecated ActiveSupport::Multibyte::Chars#tidy_bytes.
  # It replaces all ISO-8859-1 or CP1252 characters by their UTF-8 equivalent
  # resulting in a valid UTF-8 string.
  sig { params(string: String, force: T::Boolean).returns(String) }
  def self.tidy_bytes(string, force: false)
    return string if string.empty? || string.ascii_only?
    return recode_windows1252_chars(string) if force

    string.scrub { |bad| recode_windows1252_chars(bad) }
  end

  # Re-encode a string from Windows-1252 to UTF-8, replacing invalid/undefined characters
  sig { params(string: String).returns(String) }
  def self.recode_windows1252_chars(string)
    string.encode(Encoding::UTF_8, Encoding::Windows_1252,
                  invalid: :replace, undef: :replace)
  end
end
