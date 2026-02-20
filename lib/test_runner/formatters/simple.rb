# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module TestRunner
  module Formatters
    # Simple text-based formatter without animations
    class Simple < Base
      extend T::Sig

      sig { params(verbose: T::Boolean).void }
      def initialize(verbose: false)
        @verbose = verbose
      end

      sig { override.void }
      def start
        puts "Starting tasks..." if !@verbose
      end

      sig { override.void }
      def stop
        # No cleanup needed
      end

      sig { override.params(section_name: String).void }
      def start_section(section_name)
        puts "▶ Section: #{section_name}" if !@verbose
      end

      sig { override.params(section_name: String).void }
      def complete_section(section_name)
        # No action needed
      end

      sig { override.params(task: Task).void }
      def start_task(task)
        return if @verbose
        puts "▶ #{display_name(task)} started"
      end

      sig { override.params(task: Task).void }
      def complete_task(task)
        return if @verbose

        if task.skipped
          puts "⊘ #{display_name(task)} skipped: #{task.skip_reason}"
        elsif task.success?
          puts "✓ #{display_name(task)} passed in #{task.duration}s"
        else
          puts "✗ #{display_name(task)} failed in #{task.duration}s"
        end
      end

      sig { override.params(failed_tasks: T::Array[Task], verbose: T::Boolean).void }
      def print_failures(failed_tasks, verbose: false)
        return if verbose || failed_tasks.empty?

        puts
        failed_tasks.each do |task|
          puts "✗ #{task.name.to_s.tr('_', ' ')} failed in #{task.duration} seconds:"
          puts
          puts task.output
          puts
        end
      end

      sig { override.params(section_results: T::Hash[String, Result], total_duration: Float, all_passed: T::Boolean).void }
      def print_final_summary(section_results, total_duration:, all_passed:)
        puts
        section_results.each do |section_name, result|
          status = result.failed? ? "❌" : "✅"
          puts "#{status} Section '#{section_name}' - #{result.tasks.length} tasks in #{result.total_duration}s"
        end

        puts
        total_tasks = section_results.values.sum { |r| r.tasks.length }
        if all_passed
          puts "✅ All #{total_tasks} tasks passed in #{total_duration} seconds"
        else
          failed_count = section_results.values.sum { |r| r.failed_tasks.length }
          skipped_count = section_results.values.sum { |r| r.skipped_tasks.length }
          summary = "❌ #{failed_count} of #{total_tasks} tasks failed"
          summary += ", #{skipped_count} skipped" if skipped_count > 0
          puts "#{summary} in #{total_duration} seconds"
        end
        puts
      end

      sig { override.params(result: Result, verbose: T::Boolean).void }
      def print_summary(result, verbose: false)
        # Summary is printed by print_final_summary
      end

      private

      sig { params(task: Task).returns(String) }
      def display_name(task)
        name = task.name.to_s.tr("_", " ")
        name += " (autocorrect)" if task.is_autocorrect
        if task.parent
          "  #{name} (child of #{task.parent})"
        else
          name
        end
      end
    end
  end
end
