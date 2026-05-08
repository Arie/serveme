# typed: ignore
# frozen_string_literal: true
#
# Kamal 2.11 hardcodes `--network kamal` in Kamal::Commands::App#run.
# That conflicts with `--network host`, which we need for the logdaemon
# role so old + new containers can both bind UDP/40001 via SO_REUSEPORT
# during a deploy (zero loglines lost). This patch strips the hardcoded
# `--network kamal` pair only for the logdaemon role; every other role
# is untouched.
#
# Loaded automatically by bin/kamal via RUBYOPT.

require "kamal"

module Kamal::Commands::AppLogdaemonNetworkOverride
  def run(hostname: nil)
    cmd = super
    return cmd unless role&.name == "logdaemon"

    out = []
    skip_next = false
    cmd.each_with_index do |arg, i|
      if skip_next
        skip_next = false
        next
      end
      if arg == "--network" && cmd[i + 1] == "kamal"
        skip_next = true
        next
      end
      out << arg
    end
    out
  end
end
Kamal::Commands::App.prepend(Kamal::Commands::AppLogdaemonNetworkOverride)
