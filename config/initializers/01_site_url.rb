# typed: true
# frozen_string_literal: true

SITE_HOST = ENV.fetch("SITE_HOST", "localhost").freeze
SITE_URL = ENV.fetch("SITE_URL", "http://#{SITE_HOST}:3000").freeze
# The web host as game servers see it. A LAN install has no "direct." DNS
# record, so it points this at the host's IP instead.
DIRECT_HOST = ENV.fetch("DIRECT_HOST", "direct.#{SITE_HOST}").freeze
# Where game servers send their logs, received by script/logdaemon.
LOG_ADDRESS = "#{DIRECT_HOST}:#{ENV.fetch('LOG_PORT', '40001')}".freeze
LAN_MODE = ENV["SERVEME_LAN"].present?
