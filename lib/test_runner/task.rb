# typed: strict
# frozen_string_literal: true

require "open3"
require "sorbet-runtime"

module TestRunner
  # Represents a single task to be executed
  class Task
    extend T::Sig

    sig { returns(Symbol) }
    attr_reader :name

    sig { returns(T.nilable(Symbol)) }
    attr_reader :parent

    sig { returns(T::Array[Symbol]) }
    attr_reader :dependencies

    sig { returns(String) }
    attr_reader :output

    sig { returns(Float) }
    attr_reader :duration

    sig { returns(T::Boolean) }
    attr_reader :skipped

    sig { returns(T.nilable(String)) }
    attr_reader :skip_reason

    sig { returns(T::Boolean) }
    attr_reader :is_autocorrect

    sig do
      params(
        name: Symbol,
        command: T.any(String, T.proc.returns(String)),
        parent: T.nilable(Symbol),
        dependencies: T::Array[Symbol],
        is_autocorrect: T::Boolean
      ).void
    end
    def initialize(name:, command:, parent: nil, dependencies: [], is_autocorrect: false)
      @name = name
      @command = command
      @parent = parent
      @dependencies = T.let(dependencies, T::Array[Symbol])
      @is_autocorrect = is_autocorrect
      @status = T.let(nil, T.nilable(Process::Status))
      @output = T.let("", String)
      @duration = T.let(0.0, Float) # Will be set after task runs
      @skipped = T.let(false, T::Boolean)
      @skip_reason = T.let(nil, T.nilable(String))
    end

    sig { params(verbose: T::Boolean, block: T.nilable(T.proc.params(line: String).void)).void }
    def run(verbose: false, &block)
      start_time = Time.now

      command = @command.is_a?(Proc) ? @command.call : @command

      if verbose
        puts "\n$ #{command}"
        system(command)
        @status = $?
        @output = ""
      else
        @output = ""
        Open3.popen3(command) do |stdin, stdout, stderr, wait_thr|
          stdin.close
          threads = [
            Thread.new do
              stdout.each_line do |line|
                @output += line
                block&.call(line)
              end
            end,
            Thread.new do
              stderr.each_line do |line|
                @output += line
                block&.call(line)
              end
            end
          ]
          threads.each(&:join)
          @status = wait_thr.value
        end
      end

      @duration = (Time.now - start_time).round(3).to_f
    end

    sig { params(reason: String).void }
    def mark_skipped(reason:)
      @skipped = true
      @skip_reason = reason
      # Create a fake status object that always returns false for success?
      fake_status = Object.new
      fake_status.define_singleton_method(:success?) { false }
      @status = T.unsafe(fake_status)
      @output = reason
      @duration = 0.0
    end

    sig { returns(T::Boolean) }
    def success?
      return false if @skipped
      @status&.success? || false
    end

    sig { returns(T::Boolean) }
    def failed?
      return false if @skipped
      !success?
    end
  end
end
