# typed: true
# frozen_string_literal: true

class LogCopier
  extend T::Sig

  attr_accessor :reservation, :server, :logs

  sig { params(reservation: T.untyped, server: T.untyped).void }
  def initialize(reservation, server)
    @server           = server
    @reservation      = reservation
    @logs             = server.logs
  end

  sig { params(reservation: T.untyped, server: T.untyped).void }
  def self.copy(reservation, server)
    server.log_copier_class.new(reservation, server).copy
  end

  sig { void }
  def copy
    make_directory
    set_directory_permissions
    copy_logs
  end

  sig { overridable.void }
  def copy_logs
    raise NotImplementedError
  end

  sig { returns(T.untyped) }
  def directory_to_copy_to
    Rails.root.join("server_logs", reservation.id.to_s)
  end

  sig { void }
  def make_directory
    FileUtils.mkdir_p(directory_to_copy_to)
  end

  sig { void }
  def set_directory_permissions
    FileUtils.chmod_R(0o775, directory_to_copy_to)
  end
end
