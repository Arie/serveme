# typed: strict
# frozen_string_literal: true

require_relative "test_runner/task"
require_relative "test_runner/runner"
require_relative "test_runner/result"
require_relative "test_runner/formatters/base"
require_relative "test_runner/formatters/fancy"
require_relative "test_runner/formatters/simple"
require_relative "test_runner/formatters/ai"

# Generic test/task runner framework
# Supports parallel and sequential task execution with dependency management
module TestRunner
end
