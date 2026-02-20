# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module TestRunner
  module Formatters
    # AI-optimized formatter - minimal tokens, easy parsing, no animations
    # Designed to be readable by AI assistants without unnecessary visual formatting
    class Ai < Base
      extend T::Sig

      sig { params(verbose: T::Boolean).void }
      def initialize(verbose: false)
        @verbose = verbose
        @start_time = T.let(nil, T.nilable(Time))
      end

      sig { override.void }
      def start
        @start_time = Time.now
        puts "TASKS STARTING" if !@verbose
      end

      sig { override.void }
      def stop
        # No cleanup needed
      end

      sig { override.params(section_name: String).void }
      def start_section(section_name)
        puts "SECTION #{section_name}" if !@verbose
      end

      sig { override.params(section_name: String).void }
      def complete_section(section_name)
        # No action needed
      end

      sig { override.params(task: Task).void }
      def start_task(task)
        return if @verbose
        name = task.name.to_s
        name += " (autocorrect)" if task.is_autocorrect
        parent_info = task.parent ? " (parent: #{task.parent})" : ""
        puts "START #{name}#{parent_info}"
      end

      sig { override.params(task: Task).void }
      def complete_task(task)
        return if @verbose

        status = if task.skipped
          "SKIP"
        elsif task.success?
          "PASS"
        else
          "FAIL"
        end
        name = task.name.to_s
        name += " (autocorrect)" if task.is_autocorrect
        parent_info = task.parent ? " parent=#{task.parent}" : ""
        puts "#{status} #{name}#{parent_info}"

        if task.failed? && task.output.length > 0
          # Only show first and last few lines of output to save tokens
          lines = task.output.lines
          if lines.count > 10
            puts "  Output (first 3 lines):"
            lines.first(3).each { |line| puts "  #{line.strip}" }
            puts "  ... (#{lines.count - 6} lines omitted)"
            puts "  Output (last 3 lines):"
            lines.last(3).each { |line| puts "  #{line.strip}" }
          else
            puts "  Output:"
            lines.each { |line| puts "  #{line.strip}" }
          end
        end
      end

      sig { override.params(failed_tasks: T::Array[Task], verbose: T::Boolean).void }
      def print_failures(failed_tasks, verbose: false)
        # AI formatter already showed output when tasks failed, no need to repeat
      end

      sig { override.params(section_results: T::Hash[String, Result], total_duration: Float, all_passed: T::Boolean).void }
      def print_final_summary(section_results, total_duration:, all_passed:)
        puts
        puts "SUMMARY:"

        section_results.each do |section_name, result|
          status = result.failed? ? "FAILED" : "PASSED"
          puts "  Section #{section_name}: #{status} - #{result.tasks.length} tasks in #{result.total_duration}s"
        end

        total_tasks = section_results.values.sum { |r| r.tasks.length }
        passed_tasks = section_results.values.sum { |r| r.tasks.count(&:success?) }
        failed_tasks = section_results.values.sum { |r| r.failed_tasks.length }
        skipped_tasks = section_results.values.sum { |r| r.skipped_tasks.length }

        puts
        puts "  Total: #{total_tasks} tasks"
        puts "  Passed: #{passed_tasks}"
        puts "  Failed: #{failed_tasks}"
        puts "  Skipped: #{skipped_tasks}" if skipped_tasks > 0
        puts "  Duration: #{total_duration}s"
        puts
        puts "RESULT: #{all_passed ? 'SUCCESS' : 'FAILURE'}"
      end

      sig { override.params(result: Result, verbose: T::Boolean).void }
      def print_summary(result, verbose: false)
        # Summary is printed by print_final_summary
      end
    end
  end
end
