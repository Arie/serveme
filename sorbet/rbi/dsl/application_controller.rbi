# typed: strict

# DO NOT EDIT MANUALLY
# This is an autogenerated file for dynamic methods in `ApplicationController`.
# Please instead update this file by running `bin/tapioca dsl ApplicationController`.


class ApplicationController
  include GeneratedUrlHelpersModule
  include GeneratedPathHelpersModule

  sig { returns(HelperProxy) }
  def helpers; end

  module HelperMethods
    include ::Turbo::DriveHelper
    include ::Turbo::FramesHelper
    include ::Turbo::IncludesHelper
    include ::Turbo::StreamsHelper
    include ::ActionView::Helpers::CaptureHelper
    include ::ActionView::Helpers::OutputSafetyHelper
    include ::ActionView::Helpers::TagHelper
    include ::Turbo::Streams::ActionHelper
    include ::ActionText::ContentHelper
    include ::ActionText::TagHelper
    include ::Importmap::ImportmapTagsHelper
    include ::ActionController::Base::HelperMethods
    include ::ApplicationHelper
    include ::LogLineHelper
    include ::RconHelper
    include ::ReservationsHelper
    include ::SessionsHelper
    include ::FontAwesome::Rails::IconHelper
    include ::DeviseHelper

    sig { returns(T.untyped) }
    def current_admin; end

    sig { returns(T.untyped) }
    def current_league_admin; end

    sig { returns(T.untyped) }
    def current_streamer; end

    sig { returns(T.untyped) }
    def current_trusted_api; end

    sig { returns(T.untyped) }
    def time_zone_from_cookie; end
  end

  class HelperProxy < ::ActionView::Base
    include HelperMethods
  end
end
