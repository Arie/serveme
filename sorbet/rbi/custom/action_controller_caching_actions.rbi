# typed: strict

module ActionController
  module Caching
    module Actions
      extend T::Helpers
      interface!

      module ClassMethods
        extend T::Sig
        sig { params(action: T.any(Symbol, String), options: T::Hash[Symbol, T.untyped]).void }
        def caches_action(*action, **options); end

        sig { params(action: T.any(Symbol, String)).void }
        def expire_action(*action); end
      end
    end
  end
end
