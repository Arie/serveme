# typed: strict
# frozen_string_literal: true

session_key = "_serveme_sessions#{ENV['SESSION_KEY_SUFFIX']}"
Serveme::Application.config.session_store ActionDispatch::Session::CacheStore, key: session_key, expire_after: 1.month
