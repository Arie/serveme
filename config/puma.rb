# typed: ignore
# frozen_string_literal: true

# WEB_CONCURRENCY > 0 puts puma in cluster mode with that many forked
# workers. Set in deploy.eu.yml / deploy.na.yml; busy regions only.
worker_count = Integer(ENV.fetch("WEB_CONCURRENCY", 0))
workers worker_count if worker_count > 0

max_threads = Integer(ENV.fetch("RAILS_MAX_THREADS", 5))
min_threads = Integer(ENV.fetch("RAILS_MIN_THREADS", max_threads))
threads min_threads, max_threads

port ENV.fetch("PORT", 3000)
environment ENV.fetch("RAILS_ENV", "development")
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]

plugin :tmp_restart
preload_app!
