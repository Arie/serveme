# typed: strict

module ActionController
  module Caching
    include Actions
    mixes_in_class_methods Actions::ClassMethods
  end
end
