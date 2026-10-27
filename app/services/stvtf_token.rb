# typed: true
# frozen_string_literal: true

# Start links for the live STV map (stvtf-web). The token is AES-256-GCM encrypted with a key the
# map server shares, so the SourceTV password inside it is never readable in a URL:
# base64url(12-byte nonce | ciphertext | 16-byte tag) of {connect, owner, exp}, or of
# {demo, owner, exp} to play a demos.tf demo. An `owner` may watch one match at a time; nil is
# unlimited.
class StvtfToken
  extend T::Sig

  TTL = 60

  sig { returns(T::Boolean) }
  def self.enabled?
    ENV["STVTF_URL"].present? && ENV["STVTF_TOKEN_KEY"].present?
  end

  sig { params(owner: T.nilable(String), connect: T.nilable(String), demo: T.nilable(Integer)).returns(String) }
  def self.start_url(owner:, connect: nil, demo: nil)
    "#{ENV.fetch('STVTF_URL').chomp('/')}/start?t=#{generate(connect: connect, demo: demo, owner: owner)}"
  end

  # Either a connect string or a demos.tf demo id.
  sig do
    params(owner: T.nilable(String), connect: T.nilable(String), demo: T.nilable(Integer),
           now: T.any(Time, ActiveSupport::TimeWithZone)).returns(String)
  end
  def self.generate(owner:, connect: nil, demo: nil, now: Time.current)
    raise ArgumentError, "give a connect string or a demo" unless connect.nil? ^ demo.nil?

    cipher = OpenSSL::Cipher.new("aes-256-gcm").encrypt
    cipher.key = key
    nonce = cipher.random_iv
    cipher.auth_data = ""
    source = connect ? { connect: connect } : { demo: demo }
    payload = source.merge(owner: owner, exp: now.to_i + TTL).to_json
    sealed = cipher.update(payload) + cipher.final + cipher.auth_tag
    Base64.urlsafe_encode64(nonce + sealed, padding: false)
  end

  sig { returns(String) }
  def self.key
    [ ENV.fetch("STVTF_TOKEN_KEY") ].pack("H*")
  end
  private_class_method :key
end
