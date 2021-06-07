# frozen_string_literal: true

Warden.test_mode!
World Warden::Test::Helpers
After { Warden.test_reset! }
