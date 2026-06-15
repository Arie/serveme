# typed: true
# frozen_string_literal: true

class ZipFileCreator
  extend T::Sig

  attr_accessor :reservation, :files_to_zip

  sig { params(reservation: T.untyped, files_to_zip: T.untyped).void }
  def initialize(reservation, files_to_zip)
    @reservation            = reservation
    @files_to_zip           = files_to_zip
  end

  sig { params(reservation: T.untyped, files_to_zip: T.untyped).void }
  def self.create(reservation, files_to_zip)
    server = reservation.server
    server.zip_file_creator_class.new(reservation, files_to_zip).create_zip
  end

  sig { void }
  def chmod
    File.chmod(0o755, zipfile_name_and_path.to_s)
  end

  sig { returns(String) }
  def zipfile_name
    reservation.zipfile_name
  end

  sig { returns(Pathname) }
  def zipfile_name_and_path
    Rails.root.join("public", "uploads", zipfile_name)
  end

  sig { returns(T::Array[String]) }
  def shell_escaped_files_to_zip
    files_to_zip.collect(&:shellescape)
  end

  private

  sig { returns(T.untyped) }
  def server
    reservation.server
  end
end
