# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module TestRunner
  # Collection of task results with summary and query methods
  class Result
    extend T::Sig

    sig { returns(T::Array[Task]) }
    attr_reader :tasks

    sig { returns(Float) }
    attr_reader :total_duration

    sig { params(tasks: T::Array[Task], total_duration: Float).void }
    def initialize(tasks:, total_duration:)
      @tasks = tasks
      @total_duration = total_duration
    end

    sig { returns(T::Boolean) }
    def success?
      tasks.all?(&:success?)
    end

    sig { returns(T::Boolean) }
    def failed?
      !success?
    end

    sig { returns(T::Array[Task]) }
    def failed_tasks
      tasks.select(&:failed?)
    end

    sig { returns(T::Array[Task]) }
    def successful_tasks
      tasks.select(&:success?)
    end

    sig { returns(T::Array[Task]) }
    def skipped_tasks
      tasks.select(&:skipped)
    end

    sig { returns(String) }
    def summary
      if success?
        "✅ All tasks passed in #{total_duration} seconds"
      else
        failed_names = failed_tasks.map(&:name).join(", ")
        "❌ Tasks #{failed_names} failed in #{total_duration} seconds"
      end
    end
  end
end
