# typed: strict
# frozen_string_literal: true

Serveme::Application.config.session_store ActionDispatch::Session::CacheStore, key: "_serveme_sessions", expire_after: 1.month
