# typed: true
# frozen_string_literal: true

SITE_HOST = ENV.fetch("SITE_HOST", "localhost").freeze
SITE_URL = ENV.fetch("SITE_URL", "http://#{SITE_HOST}:3000").freeze
