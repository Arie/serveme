# typed: true
# frozen_string_literal: true

module LiveMapsHelper
  extend T::Sig
  extend T::Helpers

  requires_ancestor { ActionView::Base }

  ROUND_STATES = {
    "init" => "Pre-match", "pregame" => "Pre-match", "start_game" => "Pre-match", "preround" => "Setup",
    "running" => "Live", "team_win" => "Round over", "bonus" => "Round over", "between_rounds" => "Between rounds",
    "restart" => "Restarting", "stalemate" => "Stalemate", "game_over" => "Game over"
  }.freeze

  sig { params(seconds: T.nilable(Numeric)).returns(T.nilable(String)) }
  def stv_clock(seconds)
    return if seconds.nil?

    total = seconds.to_i
    Kernel.format("%d:%02d", total / 60, total % 60)
  end

  sig { params(seconds: T.nilable(Numeric)).returns(String) }
  def stv_duration(seconds)
    minutes = (seconds.to_i / 60.0).round
    return "#{minutes} min" if minutes < 60

    "#{minutes / 60} h #{Kernel.format("%02d", minutes % 60)} m"
  end

  sig { params(match: StvtfHub::Match).returns(String) }
  def stv_round_label(match)
    label = ROUND_STATES.fetch(match["round"].to_s, "Connecting")
    clock = stv_clock(match["round_time"])
    label == "Live" && clock ? "Live · #{clock}" : label
  end

  sig { params(match: StvtfHub::Match).returns(T.nilable(String)) }
  def stv_round_detail(match)
    if (left = stv_clock(match["time_left"]))
      "#{left} left"
    elsif match["win_limit"]
      "win limit #{match['win_limit']}"
    end
  end

  CLASSES = %w[scout soldier pyro demoman heavy engineer medic sniper spy].freeze

  sig { params(player: T::Hash[String, T.untyped]).returns(ActiveSupport::SafeBuffer) }
  def stv_class_icon(player)
    name = player["class"].to_s
    return tag.span(class: "class-icon", style: "background: none") unless CLASSES.include?(name)

    sprite = name == "heavy" ? "heavyweapons" : name
    tag.span(class: "class-icon class-icon-#{sprite}", title: name.capitalize)
  end

  sig { params(demo: StvtfHub::Match).returns(String) }
  def stv_demo_label(demo)
    demo["demo"] ? "demos.tf ##{demo['demo']}" : demo.id
  end

  sig { params(match: StvtfHub::Match).returns(String) }
  def stv_spectators(match)
    count = match.players("spectator").size
    count.positive? ? "+#{count} spec" : ""
  end
end
