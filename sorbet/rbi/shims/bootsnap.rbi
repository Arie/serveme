# typed: true
# frozen_string_literal: true

# Bootsnap patches JSON at runtime, but the module isn't part of Bootsnap's public API.
# Tapioca incorrectly captures this runtime patch when generating RBIs.
# This shim defines the missing constant to satisfy Sorbet.

module Bootsnap
  module CompileCache
    module JSON
      module Patch
      end
    end
  end
end
