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

  # Render the v2 variant of a partial (for sites that pre-render `html:`).
  def render_v2(partial:, locals:)
    ApplicationController.render(partial: partial, locals: locals, variants: [ VARIANT ])
  end

  # Only partial rendering can take a variant; pre-rendered `html:`/`content:`
  # payloads are passed through unchanged (caller renders the v2 html itself).
  def with_variant(rendering)
    return rendering unless rendering.key?(:partial)

    rendering.merge(variants: [ VARIANT ])
  end
end
