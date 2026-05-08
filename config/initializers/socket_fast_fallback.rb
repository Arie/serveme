# typed: false
# frozen_string_literal: true

# Ruby 3.4 enabled Happy Eyeballs (RFC 8305) by default for Socket.tcp. The
# implementation has an edge-case bug: when local_host is an IPv4-only
# address like "0.0.0.0" (which net-ssh passes through as bind_address),
# the resolution path lets the symbol :ipv4 reach Socket.new, which raises
# `SocketError: unknown socket domain: ipv4`.
#
# Surface area: any Socket.tcp call with a local bind address. Hits Net::SSH
# (cloud server RCON/SSH workers), Net::SFTP, anything that resolves a host
# while binding locally. Failure mode is intermittent, driven by DNS timing.
#
# Disabling fast-fallback reverts to the pre-Ruby-3.4 sequential connect path.
# Slightly slower for IPv6-or-IPv4 hosts, but correct in all cases.
require "socket"
Socket.tcp_fast_fallback = false
