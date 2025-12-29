# typed: true
# frozen_string_literal: true

# Shims for Pagy modules that tapioca DSL generates but don't exist in pagy 9.x
class Pagy
  module JSTools
    module FrontendAddOn; end
  end

  module BootstrapExtra; end
end
