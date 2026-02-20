# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module TestRunner
  module Formatters
    # Base formatter interface that all formatters must implement
    class Base
      extend T::Sig
      extend T::Helpers

      abstract!

      sig { abstract.void }
      def start; end

      sig { abstract.void }
      def stop; end

      sig { abstract.params(section_name: String).void }
      def start_section(section_name); end

      sig { abstract.params(section_name: String).void }
      def complete_section(section_name); end

      sig { abstract.params(task: Task).void }
      def start_task(task); end

      sig { abstract.params(task: Task).void }
      def complete_task(task); end

      sig { abstract.params(failed_tasks: T::Array[Task], verbose: T::Boolean).void }
      def print_failures(failed_tasks, verbose: false); end

      sig { abstract.params(section_results: T::Hash[String, Result], total_duration: Float, all_passed: T::Boolean).void }
      def print_final_summary(section_results, total_duration:, all_passed:); end

      sig { abstract.params(result: Result, verbose: T::Boolean).void }
      def print_summary(result, verbose: false); end
    end
  end
end
