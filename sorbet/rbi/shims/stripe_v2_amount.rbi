# typed: true
# frozen_string_literal: true

# stripe 19.x ships lib/stripe/resources/v2/amount.rb defining this class,
# but nothing in the gem requires it, so it's never loaded at runtime and
# Tapioca can't see it. The generated stripe RBI still references it in sigs.
# This shim defines the missing constant to satisfy Sorbet.

module Stripe
  module V2
    class Amount
      sig { returns(Integer) }
      def value; end

      sig { returns(String) }
      def currency; end
    end
  end
end
