# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module TestRunner
  module Formatters
    # Fancy formatter with animated progress display and tree view
    class Fancy < Base
      extend T::Sig

      FRAMES = [ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" ]
      OK = "\e[92m✓\e[0m"
      CROSS = "\e[91m✗\e[0m"
      DISPLAY_THREAD_JOIN_TIMEOUT = 0.15
      DISPLAY_UPDATE_INTERVAL = 0.1

      sig { params(verbose: T::Boolean).void }
      def initialize(verbose: false)
        @verbose = verbose
        @sections = T.let([], T::Array[T::Hash[Symbol, T.untyped]])
        @tasks = T.let({}, T::Hash[Symbol, T::Hash[Symbol, T.untyped]])
        @mutex = T.let(Mutex.new, Mutex)
        @display_thread = T.let(nil, T.nilable(Thread))
        @running = T.let(false, T::Boolean)
        @last_display_lines = T.let(0, Integer)
      end

      sig { override.void }
      def start
        puts unless @verbose
      end

      sig { override.void }
      def stop
        return if @verbose

        @mutex.synchronize { @running = false }
        if @display_thread
          @display_thread.join(DISPLAY_THREAD_JOIN_TIMEOUT)
          @display_thread.kill if @display_thread.alive?
          @display_thread = nil
        end
        print "\r\e[K"
      end

      sig { override.params(section_name: String).void }
      def start_section(section_name)
        @mutex.synchronize do
          @sections << {
            name: section_name,
            status: :running,
            tasks: [],
            start_time: Time.now,
            duration: nil
          }
        end
      end

      sig { override.params(section_name: String).void }
      def complete_section(section_name)
        @mutex.synchronize do
          section = @sections.find { |s| s[:name] == section_name }
          if section
            # Determine section status based on task results
            section_task_names = section[:tasks]
            not_success = %i[failed skipped].freeze
            has_failures = section_task_names.any? { |task_name| not_success.include?(@tasks[task_name]&.[](:status)) }
            section[:status] = has_failures ? :failed : :success
            section[:duration] = (Time.now - section[:start_time]).round(3)
          end
        end
      end

      sig { override.params(task: Task).void }
      def start_task(task)
        return if @verbose

        @mutex.synchronize do
          display_name = task.name.to_s.tr("_", " ")
          display_name += " (autocorrect)" if task.is_autocorrect
          @tasks[task.name] = {
            display_name: display_name,
            status: :running,
            start_time: Time.now,
            duration: nil,
            dependencies: task.dependencies
          }

          # Add task to current section
          current_section = @sections.last
          if current_section
            current_section[:tasks] << task.name
          end

          start_display if !@running
        end
      end

      sig { override.params(task: Task).void }
      def complete_task(task)
        return if @verbose

        @mutex.synchronize do
          task_data = @tasks[task.name]
          if task_data
            task_data[:status] = if task.skipped
              :skipped
            elsif task.success?
              :success
            else
              :failed
            end
            task_data[:duration] = task.duration
            task_data[:end_time] = Time.now
            task_data[:skip_reason] = task.skip_reason
          end
        end
      end

      sig { override.params(failed_tasks: T::Array[Task], verbose: T::Boolean).void }
      def print_failures(failed_tasks, verbose: false)
        return if verbose || failed_tasks.empty?

        puts
        puts "=" * 80
        puts "FAILED TASKS"
        puts "=" * 80

        failed_tasks.each_with_index do |task, index|
          puts if index > 0 # Blank line between failures

          puts
          puts "─" * 80
          name = task.name.to_s.tr("_", " ").upcase
          name += " (AUTOCORRECT)" if task.is_autocorrect
          puts "✗ #{name}"
          puts "  Duration: #{task.duration}s"
          puts "─" * 80
          puts
          puts task.output
        end

        puts
        puts "=" * 80
        puts
      end

      sig { override.params(section_results: T::Hash[String, Result], total_duration: Float, all_passed: T::Boolean).void }
      def print_final_summary(section_results, total_duration:, all_passed:)
        puts
        puts "━" * 80

        section_results.each do |section_name, result|
          status_icon = result.failed? ? CROSS : OK
          puts "#{status_icon} Section: #{section_name} - #{result.tasks.length} tasks in #{result.total_duration}s"
        end

        puts "━" * 80

        total_tasks = section_results.values.sum { |r| r.tasks.length }
        if all_passed
          puts "#{OK} All #{total_tasks} tasks passed in #{total_duration} seconds"
        else
          failed_tasks = section_results.values.flat_map(&:failed_tasks)
          skipped_tasks = section_results.values.flat_map(&:skipped_tasks)
          failed_count = failed_tasks.length
          skipped_count = skipped_tasks.length
          puts "#{CROSS} #{failed_count} of #{total_tasks} tasks failed in #{total_duration} seconds"
          puts
          puts "Failed tasks:"
          failed_tasks.each do |task|
            name = task.name.to_s.tr("_", " ")
            name += " (autocorrect)" if task.is_autocorrect
            puts "  #{CROSS} #{name}"
          end
          if skipped_count > 0
            puts
            puts "Skipped tasks:"
            skipped_tasks.each do |task|
              name = task.name.to_s.tr("_", " ")
              name += " (autocorrect)" if task.is_autocorrect
              puts "  \e[93m⊘\e[0m #{name}"
            end
          end
        end
        puts
      end

      sig { override.params(result: Result, verbose: T::Boolean).void }
      def print_summary(result, verbose: false)
        # Summary is printed by print_final_summary
      end

      private

      sig { void }
      def start_display
        return if @running

        @running = true
        @display_thread = Thread.new do
          frame_index = 0

          loop do
            @mutex.synchronize do
              if @last_display_lines > 0 && frame_index > 0
                print "\e[#{@last_display_lines}A\e[J"
              end

              # Build dependency tree and display it
              lines_displayed = display_dependency_tree(frame_index)
              @last_display_lines = lines_displayed
            end

            # T.unsafe needed because Sorbet doesn't understand @running can change from another thread
            break if !T.unsafe(@running)
            frame_index += 1
            sleep DISPLAY_UPDATE_INTERVAL
          end
        end
      end

      sig { params(frame_index: Integer).returns(Integer) }
      def display_dependency_tree(frame_index)
        lines = 0

        # Display all sections
        @sections.each do |section|
          section_name = section[:name]
          section_status = section[:status]
          section_task_names = section[:tasks]

          # Display section header
          case section_status
          when :running
            elapsed = (Time.now - section[:start_time]).round(1)
            spinner = "\e[96m#{FRAMES[frame_index % FRAMES.size]}\e[0m"
            puts "#{spinner} Section: #{section_name} (#{elapsed}s)"
          when :success
            puts "#{OK} Section: #{section_name} (#{section[:duration]}s)"
          when :failed
            puts "#{CROSS} Section: #{section_name} (#{section[:duration]}s)"
          end
          lines += 1

          # Build dependency graph for this section
          # A task is a root if it has no dependencies, or all its dependencies
          # are outside this section (e.g. pre-completed from a previous section)
          roots = section_task_names.select do |name|
            task_data = @tasks[name]
            task_data && task_data[:dependencies].all? { |dep| !section_task_names.include?(dep) }
          end

          # Display root tasks and their dependents
          roots.each_with_index do |root_name, root_index|
            is_last_root = root_index == roots.length - 1
            lines += display_task_tree(root_name, "  ", is_last_root, frame_index, section_task_names)
          end
        end

        lines
      end

      sig { params(task_name: Symbol, prefix: String, is_last: T::Boolean, frame_index: Integer, all_tasks: T::Array[Symbol]).returns(Integer) }
      def display_task_tree(task_name, prefix, is_last, frame_index, all_tasks)
        lines = 0
        task_data = @tasks[task_name]
        return lines if task_data.nil?

        # Display current task
        branch = is_last ? "└─ " : "├─ "
        full_prefix = prefix.empty? ? "" : prefix + branch

        case task_data[:status]
        when :running
          elapsed = Time.now - task_data[:start_time]
          spinner = "\e[96m#{FRAMES[frame_index % FRAMES.size]}\e[0m"
          puts "#{full_prefix}#{spinner} #{task_data[:display_name]} (#{elapsed.round(1)}s)"
        when :success
          puts "#{full_prefix}#{OK} #{task_data[:display_name]} passed in #{task_data[:duration]} seconds"
        when :failed
          puts "#{full_prefix}#{CROSS} #{task_data[:display_name]} failed in #{task_data[:duration]} seconds"
        when :skipped
          skip = "\e[93m⊘\e[0m"
          puts "#{full_prefix}#{skip} #{task_data[:display_name]} skipped: #{task_data[:skip_reason]}"
        end
        lines += 1

        # Find and display dependent tasks
        dependents = all_tasks.select do |name|
          task = @tasks[name]
          if task
            deps = task[:dependencies]
            deps.include?(task_name)
          else
            false
          end
        end

        if dependents.any?
          child_prefix = prefix + (is_last ? "   " : "│  ")
          dependents.each_with_index do |dependent_name, dep_index|
            is_last_dependent = dep_index == dependents.length - 1
            lines += display_task_tree(dependent_name, child_prefix, is_last_dependent, frame_index, all_tasks)
          end
        end

        lines
      end
    end
  end
end
