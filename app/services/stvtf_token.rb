# typed: true
# frozen_string_literal: true

# Start links for the live STV map (stvtf-web). The token is AES-256-GCM encrypted with a key the
# map server shares, so the SourceTV password inside it is never readable in a URL:
# base64url(12-byte nonce | ciphertext | 16-byte tag) of {connect, owner, exp}, or of
# {demo, owner, exp} to play a demos.tf demo. `owner` is the user's Steam uid, which the map server
# only logs: it limits nothing. `reservation` links the match to a reservation; {list, exp} reads the
# hub's list of matches; {signin: {uid, name, streamer}, exp} signs a user in to its rooms. The map
# server seals one itself, {link, exp}, to ask who a Discord user is (StvtfDiscordLinksController).
class StvtfToken
  extend T::Sig

  TTL = 60

  sig { returns(T::Boolean) }
  def self.enabled?
    ENV["STVTF_URL"].present? && ENV["STVTF_TOKEN_KEY"].present?
  end

  sig { returns(String) }
  def self.base_url
    ENV.fetch("STVTF_URL").chomp("/")
  end

  sig { params(owner: T.nilable(String), connect: T.nilable(String), demo: T.nilable(Integer), reservation: T.nilable(Integer)).returns(String) }
  def self.start_url(owner:, connect: nil, demo: nil, reservation: nil)
    "#{base_url}/start?t=#{generate(connect: connect, demo: demo, owner: owner, reservation: reservation)}"
  end

  # Back to the map server at `path`, signing `user` in to its rooms: their Steam uid, name, and
  # whether they are a streamer or more here, who may make themselves admin in any room.
  sig { params(user: User, path: String, now: T.any(Time, ActiveSupport::TimeWithZone)).returns(String) }
  def self.sign_in_url(user:, path:, now: Time.current)
    signin = { uid: user.uid, name: user.nickname.presence || user.name, streamer: user.streamer? || user.admin? || user.league_admin? }
    "#{base_url}/signed_in?t=#{seal({ signin: signin, exp: now.to_i + TTL })}&return=#{CGI.escape(path)}"
  end

  sig { params(now: T.any(Time, ActiveSupport::TimeWithZone)).returns(String) }
  def self.list_token(now: Time.current)
    seal({ list: true, exp: now.to_i + TTL })
  end

  # Either a connect string or a demos.tf demo id.
  sig do
    params(owner: T.nilable(String), connect: T.nilable(String), demo: T.nilable(Integer), reservation: T.nilable(Integer),
           now: T.any(Time, ActiveSupport::TimeWithZone)).returns(String)
  end
  def self.generate(owner:, connect: nil, demo: nil, reservation: nil, now: Time.current)
    raise ArgumentError, "give a connect string or a demo" unless connect.nil? ^ demo.nil?

    source = connect ? { connect: connect } : { demo: demo }
    claims = source.merge(owner: owner, exp: now.to_i + TTL)
    claims[:reservation] = reservation if reservation
    seal(claims)
  end

  # Whether `token` is the map server's, asking who Discord user `discord_uid` is: {link, exp},
  # sealed as above.
  sig { params(token: String, discord_uid: String, now: T.any(Time, ActiveSupport::TimeWithZone)).returns(T::Boolean) }
  def self.link?(token, discord_uid, now: Time.current)
    claims = open(token)
    !claims.nil? && discord_uid.present? && claims["link"] == discord_uid && claims["exp"].is_a?(Integer) && claims["exp"] >= now.to_i
  end

  sig { params(token: String).returns(T.nilable(T::Hash[String, T.untyped])) }
  def self.open(token)
    raw = Base64.urlsafe_decode64(token)
    return nil if raw.bytesize < 12 + 16

    cipher = OpenSSL::Cipher.new("aes-256-gcm").decrypt
    cipher.key = key
    cipher.iv = raw.byteslice(0, 12)
    cipher.auth_tag = raw.byteslice(-16, 16)
    cipher.auth_data = ""
    claims = JSON.parse(cipher.update(raw.byteslice(12, raw.bytesize - 28)) + cipher.final)
    claims.is_a?(Hash) ? claims : nil
  rescue ArgumentError, OpenSSL::Cipher::CipherError, JSON::ParserError
    nil
  end

  sig { params(claims: T::Hash[Symbol, T.untyped]).returns(String) }
  def self.seal(claims)
    cipher = OpenSSL::Cipher.new("aes-256-gcm").encrypt
    cipher.key = key
    nonce = cipher.random_iv
    cipher.auth_data = ""
    sealed = cipher.update(claims.to_json) + cipher.final + cipher.auth_tag
    Base64.urlsafe_encode64(nonce + sealed, padding: false)
  end

  sig { returns(String) }
  def self.key
    [ ENV.fetch("STVTF_TOKEN_KEY") ].pack("H*")
  end
  private_class_method :key, :seal, :open
end
