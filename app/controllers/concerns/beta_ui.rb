# typed: false
# frozen_string_literal: true

# Opt-in redesign gating. A user sets the `ui_v2` cookie via /beta; when set AND
# a `+v2` template exists for the current controller#action, we render the `:v2`
# template variant inside the `application_v2` layout. Everything else is untouched,
# so non-opted-in users (and not-yet-converted pages) see the current site.
#
# Coverage is auto-detected by scanning for `*.html+v2.haml` templates, so adding a
# view to the redesign is just a matter of dropping the `+v2` file — no central
# registry to keep in sync.
module BetaUi
  extend ActiveSupport::Concern

  # Rails re-renders :new from #create and :edit from #update on validation
  # failure. Those actions have no +v2 template of their own, so treat them as
  # redesigned when the template they fall back to is.
  CONVENTIONAL_TEMPLATES = { "create" => "new", "update" => "edit" }.freeze

  included do
    before_action :set_beta_variant
    helper_method :beta_ui?, :v2_stylesheet_href
  end

  class_methods do
    # Declare the template an action actually renders, so beta variant detection
    # matches it instead of the (template-less) action name. Pass a symbol when
    # every action renders the same template (e.g. show_for_* actions that
    # `render :index`), or a Hash for per-action mapping (e.g. `fetch: :preview`).
    def beta_renders_as(mapping)
      if mapping.is_a?(Hash)
        @beta_render_map = beta_render_map.merge(mapping.transform_keys(&:to_s).transform_values(&:to_s))
      else
        @beta_render_target = mapping.to_s
      end
    end

    def beta_render_target
      @beta_render_target
    end

    def beta_render_map
      @beta_render_map ||= {}
    end
  end

  class << self
    # "controller_path/action" strings that have a `+v2` template.
    def v2_templates
      if Rails.env.development?
        scan_v2_templates
      else
        @v2_templates ||= scan_v2_templates
      end
    end

    def v2_redesigned?(controller_path, action_name)
      v2_templates.include?("#{controller_path}/#{action_name}")
    end

    def scan_v2_templates
      base = Rails.root.join("app/views")
      Dir.glob(base.join("**/*.html+v2.haml")).map do |path|
        Pathname.new(path).relative_path_from(base).to_s.sub(/\.html\+v2\.haml\z/, "")
      end.to_set
    end
  end

  private

  def beta_ui?
    cookies[:ui_v2] == "true"
  end

  # The redesign bundle is a static file in public/ (it bypasses Sprockets/SassC).
  # Append the build mtime as a cache-busting query so updated CSS is picked up
  # across deploys and dev rebuilds.
  def v2_stylesheet_href
    path = Rails.public_path.join("builds/v2.css")
    return "/builds/v2.css" unless File.exist?(path)

    "/builds/v2.css?v=#{File.mtime(path).to_i}"
  end

  def beta_redesigned_action?
    target = self.class.beta_render_target
    return BetaUi.v2_redesigned?(controller_path, target) if target

    return true if BetaUi.v2_redesigned?(controller_path, action_name)

    fallback = self.class.beta_render_map[action_name] || CONVENTIONAL_TEMPLATES[action_name]
    fallback.present? && BetaUi.v2_redesigned?(controller_path, fallback)
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
