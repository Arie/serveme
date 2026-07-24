# typed: true
# frozen_string_literal: true

# Estimates a reservation's provisioning/ending progress from its status history
# (pure computation, no server I/O). CloudServer keeps its own provider-specific
# provision_estimate and reaches this base end_estimate via super.
class ServerReservationEstimator
  extend T::Sig

  FAST_START_PHASES = [
    { key: "sending_configs", label: "Sending configs", icon: "fa-cog", seconds: 3 },
    { key: "changing_map", label: "Changing map", icon: "fa-map", seconds: 5 },
    { key: "waiting_for_server", label: "Waiting for server", icon: "fa-gamepad", seconds: 5 }
  ].freeze

  RESTART_PHASES = [
    { key: "sending_configs", label: "Sending configs", icon: "fa-cog", seconds: 3 },
    { key: "restarting", label: "Restarting server", icon: "fa-refresh", seconds: 20 },
    { key: "waiting_for_start", label: "Waiting for start", icon: "fa-hourglass-half", seconds: 10 },
    { key: "changing_map", label: "Changing map", icon: "fa-map", seconds: 10 }
  ].freeze

  END_PHASES = [
    { key: "ending", label: "Ending reservation", icon: "fa-stop", seconds: 2 },
    { key: "restarting", label: "Restarting server", icon: "fa-refresh", seconds: 2 },
    { key: "downloading", label: "Downloading logs", icon: "fa-download", seconds: 2 },
    { key: "zipping", label: "Zipping files", icon: "fa-file-archive", seconds: 2 }
  ].freeze

  sig { params(reservation: Reservation).void }
  def initialize(reservation)
    @reservation = reservation
  end

  sig { returns(T.nilable(T::Hash[Symbol, T.untyped])) }
  def provision_estimate
    statuses = @reservation.reservation_statuses.pluck(:status, :created_at)
    restarting = statuses.any? { |s, _| s.match?(/outdated|Restarted server|Fast start failed/) }
    phases = restarting ? RESTART_PHASES : FAST_START_PHASES

    if @reservation.ready_at.present?
      return { phases: phases, completed: true }
    end

    return if statuses.empty?

    last_status, last_status_at = statuses.last
    current_phase = provision_current_phase(T.must(last_status))
    return unless current_phase

    {
      phases: phases,
      current_phase: current_phase,
      phase_started_at: last_status_at
    }
  end

  sig { returns(T.nilable(T::Hash[Symbol, T.untyped])) }
  def end_estimate
    statuses = @reservation.reservation_statuses.pluck(:status, :created_at)
    return unless statuses.any? { |s, _| s == "Ending" }
    return if statuses.any? { |s, _| s.match?(/Finished zipping/) }

    last_status, last_status_at = statuses.last
    current_phase = end_current_phase(T.must(last_status))
    return unless current_phase

    {
      phases: END_PHASES,
      current_phase: current_phase,
      phase_started_at: last_status_at
    }
  end

  private

  sig { params(last_status: String).returns(T.nilable(String)) }
  def provision_current_phase(last_status)
    case last_status
    when /Sending reservation config/, /Enabling plugins/, /Enabled plugins/,
         /Enabling demos/, /Enabled demos/, /Disabling RGL/, /Setting RGL/, /Starting/,
         /Map .* not on the server/, /Uploaded map/, /Finished sending/
      "sending_configs"
    when /Attempting fast start/
      "changing_map"
    when /outdated/, /Fast start failed/
      "restarting"
    when /Restarted server/
      "waiting_for_start"
    when /Fast start attempted/, /startup complete, switching map/
      "waiting_for_server"
    end
  end

  sig { params(last_status: String).returns(T.nilable(String)) }
  def end_current_phase(last_status)
    case last_status
    when /\AEnding\z/
      "ending"
    when /Restarting server/
      "restarting"
    when /Restarted server/, /Downloading logs and demos/
      "downloading"
    when /Finished downloading/, /Zipping logs and demos/, /Zipping logs and demos of locally/
      "zipping"
    end
  end
end
