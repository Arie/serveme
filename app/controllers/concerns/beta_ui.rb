# typed: false
# frozen_string_literal: true

# Opt-in redesign gating. A user sets the `ui_v2` cookie via /beta; when set AND
# the current controller#action is on the allow-list below, we render the `:v2`
# template variant inside the `application_v2` layout. Everything else is untouched,
# so non-opted-in users (and not-yet-redesigned pages) see the current site.
module BetaUi
  extend ActiveSupport::Concern

  # NOTE: before adding an action here, make sure any `caches_action` on it
  # varies its cache key by `cookies[:ui_v2]` (see PagesController#welcome).
  # Otherwise an opted-in request can prime/serve the v2 HTML to non-opted-in
  # users (and vice versa) for cached actions.
  REDESIGNED_ACTIONS = {
    "pages" => %w[welcome]
  }.freeze

  included do
    before_action :set_beta_variant
    helper_method :beta_ui?
  end

  private

  def beta_ui?
    cookies[:ui_v2] == "true"
  end

  def beta_redesigned_action?
    REDESIGNED_ACTIONS[controller_name]&.include?(action_name) || false
  end

  def beta_active?
    beta_ui? && beta_redesigned_action?
  end

  def set_beta_variant
    request.variant = :v2 if beta_active?
  end

  def resolve_layout
    beta_active? ? "application_v2" : nil
  end
end
