# typed: strict
# frozen_string_literal: true

# Shim for Devise controller helpers that are dynamically generated.
# These methods are defined at runtime based on the User model.

class ActionController::Base
  # Devise's authenticate_user! method. ApplicationController overrides this.
  sig { params(opts: T::Hash[Symbol, T.untyped]).void }
  def authenticate_user!(opts = {}); end

  # Returns T.untyped because Devise dynamically generates this method
  # and it's often called after user_signed_in? checks which Sorbet can't track
  sig { returns(T.untyped) }
  def current_user; end

  sig { returns(T::Boolean) }
  def user_signed_in?; end

  sig { returns(T.untyped) }
  def user_session; end

  sig { params(resource: T.untyped).returns(T.untyped) }
  def sign_in(resource); end

  sig { params(resource_or_scope: T.untyped).void }
  def sign_out(resource_or_scope); end

  sig { params(resource_or_scope: T.untyped).returns(T.untyped) }
  def sign_out_and_redirect(resource_or_scope); end

  sig { returns(T::Boolean) }
  def devise_controller?; end

  sig { params(scope: Symbol, resource: T.untyped).void }
  def store_location_for(scope, resource); end

  sig { returns(String) }
  def new_session_path; end

  # Turbo stream helper
  sig { returns(T.untyped) }
  def turbo_stream; end
end

# Turbo stream MIME type support for respond_to blocks
class ActionController::MimeResponds::Collector
  sig { params(block: T.nilable(T.proc.void)).void }
  def turbo_stream(&block); end
end
