# typed: true
# frozen_string_literal: true

# Start links for the live STV map (stvtf-web). The token is AES-256-GCM encrypted with a key the
# map server shares, so the SourceTV password inside it is never readable in a URL:
# base64url(12-byte nonce | ciphertext | 16-byte tag) of {connect, owner, exp}. A user (`owner`)
# watches one match at a time; admins, league admins and streamers pass none and are unlimited.
class StvtfToken
  extend T::Sig

  TTL = 60

  sig { returns(T::Boolean) }
  def self.enabled?
    ENV["STVTF_URL"].present? && ENV["STVTF_TOKEN_KEY"].present?
  end

  sig { params(connect: String, owner: T.nilable(String)).returns(String) }
  def self.start_url(connect:, owner:)
    "#{ENV.fetch('STVTF_URL').chomp('/')}/start?t=#{generate(connect: connect, owner: owner)}"
  end

  sig { params(connect: String, owner: T.nilable(String), now: T.any(Time, ActiveSupport::TimeWithZone)).returns(String) }
  def self.generate(connect:, owner:, now: Time.current)
    cipher = OpenSSL::Cipher.new("aes-256-gcm").encrypt
    cipher.key = key
    nonce = cipher.random_iv
    cipher.auth_data = ""
    payload = { connect: connect, owner: owner, exp: now.to_i + TTL }.to_json
    sealed = cipher.update(payload) + cipher.final + cipher.auth_tag
    Base64.urlsafe_encode64(nonce + sealed, padding: false)
  end

  sig { returns(String) }
  def self.key
    [ ENV.fetch("STVTF_TOKEN_KEY") ].pack("H*")
  end
  private_class_method :key
end
