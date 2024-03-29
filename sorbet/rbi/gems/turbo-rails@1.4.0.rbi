# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `turbo-rails` gem.
# Please instead update this file by running `bin/tapioca gem turbo-rails`.

# source://turbo-rails//lib/turbo/test_assertions.rb#1
module Turbo
  extend ::ActiveSupport::Autoload

  class << self
    # source://railties/7.0.5/lib/rails/engine.rb#405
    def railtie_helpers_paths; end

    # source://railties/7.0.5/lib/rails/engine.rb#394
    def railtie_namespace; end

    # source://railties/7.0.5/lib/rails/engine.rb#409
    def railtie_routes_url_helpers(include_path_helpers = T.unsafe(nil)); end

    # source://turbo-rails//lib/turbo-rails.rb#9
    def signed_stream_verifier; end

    # source://turbo-rails//lib/turbo-rails.rb#13
    def signed_stream_verifier_key; end

    # Sets the attribute signed_stream_verifier_key
    #
    # @param value the value to set the attribute signed_stream_verifier_key to.
    #
    # source://turbo-rails//lib/turbo-rails.rb#7
    def signed_stream_verifier_key=(_arg0); end

    # source://railties/7.0.5/lib/rails/engine.rb#397
    def table_name_prefix; end

    # source://railties/7.0.5/lib/rails/engine.rb#401
    def use_relative_model_naming?; end
  end
end

module Turbo::Broadcastable
  extend ::ActiveSupport::Concern

  mixes_in_class_methods ::Turbo::Broadcastable::ClassMethods

  def broadcast_action(action, target: T.unsafe(nil), **rendering); end
  def broadcast_action_later(action:, target: T.unsafe(nil), **rendering); end
  def broadcast_action_later_to(*streamables, action:, target: T.unsafe(nil), **rendering); end
  def broadcast_action_to(*streamables, action:, target: T.unsafe(nil), **rendering); end
  def broadcast_after_to(*streamables, target:, **rendering); end
  def broadcast_append(target: T.unsafe(nil), **rendering); end
  def broadcast_append_later(target: T.unsafe(nil), **rendering); end
  def broadcast_append_later_to(*streamables, target: T.unsafe(nil), **rendering); end
  def broadcast_append_to(*streamables, target: T.unsafe(nil), **rendering); end
  def broadcast_before_to(*streamables, target:, **rendering); end
  def broadcast_prepend(target: T.unsafe(nil), **rendering); end
  def broadcast_prepend_later(target: T.unsafe(nil), **rendering); end
  def broadcast_prepend_later_to(*streamables, target: T.unsafe(nil), **rendering); end
  def broadcast_prepend_to(*streamables, target: T.unsafe(nil), **rendering); end
  def broadcast_remove; end
  def broadcast_remove_to(*streamables, target: T.unsafe(nil)); end
  def broadcast_render(**rendering); end
  def broadcast_render_later(**rendering); end
  def broadcast_render_later_to(*streamables, **rendering); end
  def broadcast_render_to(*streamables, **rendering); end
  def broadcast_replace(**rendering); end
  def broadcast_replace_later(**rendering); end
  def broadcast_replace_later_to(*streamables, **rendering); end
  def broadcast_replace_to(*streamables, **rendering); end
  def broadcast_update(**rendering); end
  def broadcast_update_later(**rendering); end
  def broadcast_update_later_to(*streamables, **rendering); end
  def broadcast_update_to(*streamables, **rendering); end

  private

  def broadcast_rendering_with_defaults(options); end
  def broadcast_target_default; end
end

module Turbo::Broadcastable::ClassMethods
  def broadcast_target_default; end
  def broadcasts(stream = T.unsafe(nil), inserts_by: T.unsafe(nil), target: T.unsafe(nil), **rendering); end
  def broadcasts_to(stream, inserts_by: T.unsafe(nil), target: T.unsafe(nil), **rendering); end
end

module Turbo::DriveHelper
  def turbo_exempts_page_from_cache; end
  def turbo_exempts_page_from_preview; end
  def turbo_page_requires_reload; end
end

# source://turbo-rails//lib/turbo/engine.rb#5
class Turbo::Engine < ::Rails::Engine; end

# If you don't want to precompile Turbo's assets (eg. because you're using webpack),
# you can do this in an intiailzer:
#
# config.after_initialize do
#   config.assets.precompile -= Turbo::Engine::PRECOMPILE_ASSETS
# end
#
# source://turbo-rails//lib/turbo/engine.rb#29
Turbo::Engine::PRECOMPILE_ASSETS = T.let(T.unsafe(nil), Array)

module Turbo::FramesHelper
  def turbo_frame_tag(*ids, src: T.unsafe(nil), target: T.unsafe(nil), **attributes, &block); end
end

module Turbo::IncludesHelper
  def turbo_include_tags; end
end

class Turbo::StreamsChannel < ::ActionCable::Channel::Base; end

module Turbo::StreamsHelper
  def turbo_stream; end
  def turbo_stream_from(*streamables, **attributes); end
end

# source://turbo-rails//lib/turbo/test_assertions.rb#2
module Turbo::TestAssertions
  extend ::ActiveSupport::Concern

  # source://turbo-rails//lib/turbo/test_assertions.rb#19
  def assert_no_turbo_stream(action:, target: T.unsafe(nil), targets: T.unsafe(nil)); end

  # source://turbo-rails//lib/turbo/test_assertions.rb#10
  def assert_turbo_stream(action:, target: T.unsafe(nil), targets: T.unsafe(nil), status: T.unsafe(nil), &block); end
end
