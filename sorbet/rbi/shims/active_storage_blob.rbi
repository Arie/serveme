# typed: true

class ActiveStorage::Blob
  sig { params(io: T.untyped, filename: T.untyped, content_type: T.untyped, metadata: T.untyped, service_name: T.untyped, identify: T::Boolean, record: T.untyped).returns(T.nilable(ActiveStorage::Blob)) }
  def self.create_and_upload!(io:, filename:, content_type: nil, metadata: nil, service_name: nil, identify: true, record: nil); end

  sig { params(filename: T.untyped, byte_size: Integer, checksum: String, key: T.untyped, content_type: T.untyped, metadata: T.untyped, service_name: T.untyped, record: T.untyped).returns(ActiveStorage::Blob) }
  def self.create_before_direct_upload!(filename:, byte_size:, checksum:, key: nil, content_type: nil, metadata: nil, service_name: nil, record: nil); end

  sig { returns(T.untyped) }
  def self.service; end

  sig { void }
  def purge; end

  sig { params(attributes: T.untyped).void }
  def update!(**attributes); end
end
