# typed: false
# frozen_string_literal: true

# Turbo broadcasts run with no HTTP request, so they can't see the per-user `ui_v2`
# cookie and always render the classic (non-variant) partial. And because a Turbo
# stream is shared by every subscriber, a single broadcast can't render per-user.
#
# So beta (v2) pages subscribe to a parallel ":v2"-suffixed stream, and every
# broadcast whose partial has a divergent +v2 variant is emitted twice: the classic
# partial to the original stream, and the :v2 variant to the parallel stream. Classic
# pages never see the v2 stream and vice-versa.
#
# Views subscribe to the parallel stream with the `turbo_stream_from_beta` helper;
# broadcast sites call BetaBroadcast.replace/update/append/prepend instead of the
# matching Turbo::StreamsChannel method.
module BetaBroadcast
  VARIANT = :v2

  module_function

  # The parallel beta stream for a given stream identifier (model, string, or array).
  def stream(streamables)
    Array(streamables) + [ VARIANT ]
  end

  def replace(streamables, **rendering)
    Turbo::StreamsChannel.broadcast_replace_to(*Array(streamables), **rendering)
    Turbo::StreamsChannel.broadcast_replace_to(*stream(streamables), **with_variant(rendering))
  end

  def update(streamables, **rendering)
    Turbo::StreamsChannel.broadcast_update_to(*Array(streamables), **rendering)
    Turbo::StreamsChannel.broadcast_update_to(*stream(streamables), **with_variant(rendering))
  end

  def append(streamables, **rendering)
    Turbo::StreamsChannel.broadcast_append_to(*Array(streamables), **rendering)
    Turbo::StreamsChannel.broadcast_append_to(*stream(streamables), **with_variant(rendering))
  end

  def prepend(streamables, **rendering)
    Turbo::StreamsChannel.broadcast_prepend_to(*Array(streamables), **rendering)
    Turbo::StreamsChannel.broadcast_prepend_to(*stream(streamables), **with_variant(rendering))
  end

  # Render the v2 variant of a partial.
  #
  # NB: we can't just pass `variants: [:v2]` to ApplicationController.render —
  # that option only applies the variant to the top-level template lookup and
  # is NOT stored on the lookup context, so any nested `render` inside the
  # partial (e.g. a list partial rendering a row partial) silently falls back
  # to the classic template. Setting `request.variant` instead — the same thing
  # a real beta request does — makes the :v2 variant propagate through every
  # nested partial.
  def render_v2(partial:, locals:)
    controller = ApplicationController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.request.variant = VARIANT
    controller.response = ActionDispatch::Response.new
    controller.render_to_string(partial: partial, locals: locals)
  end

  # Pre-render the v2 html ourselves (with the variant propagating to nested
  # partials, see render_v2) and broadcast it via `html:`. Pre-rendered
  # `html:`/`content:` payloads (no `:partial`) are passed through unchanged.
  def with_variant(rendering)
    return rendering unless rendering.key?(:partial)

    rendering.except(:partial, :locals).merge(html: render_v2(partial: rendering[:partial], locals: rendering[:locals] || {}))
  end
end
