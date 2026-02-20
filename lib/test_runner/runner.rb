# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module TestRunner
  # Main runner that orchestrates task execution with dependency management
  class Runner
    extend T::Sig

    # Task definition with dependencies
    class TaskDefinition < T::Struct
      const :name, Symbol
      const :command, T.any(String, T.proc.returns(String))
      const :depends_on, T::Array[Symbol], default: []
      const :parent, T.nilable(Symbol), default: nil
      const :skip_if_parent_failed, T::Boolean, default: false
      const :run_after_parent, T::Boolean, default: false
      const :is_autocorrect, T::Boolean, default: false
    end

    sig { params(formatter: Formatters::Base, verbose: T::Boolean, manage_formatter: T::Boolean, fail_fast: T::Boolean).void }
    def initialize(formatter:, verbose: false, manage_formatter: true, fail_fast: false)
      @formatter = formatter
      @verbose = verbose
      @manage_formatter = T.let(manage_formatter, T::Boolean)
      @fail_fast = T.let(fail_fast, T::Boolean)
      @task_definitions = T.let({}, T::Hash[Symbol, TaskDefinition])
      @completed_tasks = T.let({}, T::Hash[Symbol, Task])
      @pre_completed_names = T.let({}, T::Hash[Symbol, T::Boolean])
      @mutex = T.let(Mutex.new, Mutex)
    end

    sig do
      params(
        name: Symbol,
        command: T.any(String, T.proc.returns(String)),
        depends_on: T::Array[Symbol],
        parent: T.nilable(Symbol),
        skip_if_parent_failed: T::Boolean,
        run_after_parent: T::Boolean,
        is_autocorrect: T::Boolean
      ).void
    end
    def define_task(name:, command:, depends_on: [], parent: nil, skip_if_parent_failed: false, run_after_parent: false, is_autocorrect: false)
      @task_definitions[name] = TaskDefinition.new(
        name: name,
        command: command,
        depends_on: depends_on,
        parent: parent,
        skip_if_parent_failed: skip_if_parent_failed,
        run_after_parent: run_after_parent,
        is_autocorrect: is_autocorrect
      )
    end

    # Mark a task as already completed from a previous section run.
    # Dependencies on this task will be satisfied without re-executing it.
    sig { params(name: Symbol).void }
    def pre_complete_task(name:)
      task = Task.new(name: name, command: "true", dependencies: [])
      fake_status = Object.new
      fake_status.define_singleton_method(:success?) { true }
      task.instance_variable_set(:@status, T.unsafe(fake_status))
      task.instance_variable_set(:@duration, 0.0)
      @completed_tasks[name] = task
      @pre_completed_names[name] = true
    end

    sig { returns(Result) }
    def run
      @formatter.start if @manage_formatter
      all_tasks = []
      all_threads = []
      start_time = Time.now
      threads_mutex = Mutex.new

      # Find tasks that can start immediately (no dependencies)
      independent_tasks = @task_definitions.values.select { |td| td.depends_on.empty? && !td.run_after_parent }

      # Run independent tasks in parallel
      threads = independent_tasks.map do |task_def|
        Thread.new do
          task = execute_task(task_def)
          Thread.current[:task] = task
          @mutex.synchronize { @completed_tasks[task.name] = task }

          # Check if any tasks should run after this one
          trigger_dependent_tasks(task, all_tasks, all_threads, threads_mutex)
          task
        end
      end

      threads_mutex.synchronize { all_threads.concat(threads) }

      # Trigger dependents for pre-completed tasks (from previous sections)
      @pre_completed_names.each_key do |pre_name|
        pre_task = @completed_tasks[pre_name]
        trigger_dependent_tasks(pre_task, all_tasks, all_threads, threads_mutex) if pre_task
      end

      # Wait until all defined tasks have been completed
      # (checking threads doesn't work because new threads are created dynamically)
      loop do
        remaining = @mutex.synchronize do
          @task_definitions.keys - @completed_tasks.keys
        end

        break if remaining.empty?
        sleep 0.05
      end

      # Collect all completed tasks (excluding pre-completed ones from previous sections)
      @mutex.synchronize do
        all_tasks.concat(@completed_tasks.values.reject { |t| @pre_completed_names.key?(t.name) })
      end

      elapsed = (Time.now - start_time).round(3)
      total_duration = T.let(elapsed.to_f, Float)
      @formatter.stop if @manage_formatter

      Result.new(tasks: all_tasks, total_duration: total_duration)
    end

    private

    sig { params(task_def: TaskDefinition).returns(Task) }
    def execute_task(task_def)
      task = Task.new(
        name: task_def.name,
        command: task_def.command,
        parent: task_def.parent,
        dependencies: task_def.depends_on,
        is_autocorrect: task_def.is_autocorrect
      )

      # Check if we should skip due to parent failure
      parent = task_def.parent
      if task_def.skip_if_parent_failed && parent
        parent_task = @completed_tasks[parent]
        if parent_task && parent_task.failed?
          task.mark_skipped(reason: "Skipped due to #{parent} failure")
          @formatter.complete_task(task)
          return task
        end
      end

      @formatter.start_task(task)

      task.run(verbose: @verbose)

      @formatter.complete_task(task)
      task
    end

    sig { params(task: Task, all_tasks: T::Array[Task], all_threads: T::Array[Thread], threads_mutex: Mutex).void }
    def trigger_dependent_tasks(task, all_tasks, all_threads, threads_mutex)
      # Find tasks that depend on this task or should run after it
      dependent_tasks = @task_definitions.values.select do |td|
        (td.depends_on.include?(task.name) || (td.run_after_parent && td.parent == task.name)) &&
          !@completed_tasks.key?(td.name)
      end

      dependent_tasks.each do |task_def|
        # Check if all dependencies are met
        next if task_def.depends_on.any? { |dep| !@completed_tasks.key?(dep) }

        # Check if all dependencies succeeded (if required)
        if task_def.skip_if_parent_failed
          dependencies_failed = task_def.depends_on.any? { |dep| @completed_tasks[dep]&.failed? }
          if dependencies_failed
            # Create a skipped task
            skipped_task = Task.new(
              name: task_def.name,
              command: task_def.command,
              parent: task_def.parent,
              dependencies: task_def.depends_on,
              is_autocorrect: task_def.is_autocorrect
            )
            parent_name = task_def.parent || task_def.depends_on.first
            skipped_task.mark_skipped(reason: "Skipped due to #{parent_name} failure")
            @formatter.complete_task(skipped_task)
            @mutex.synchronize { @completed_tasks[skipped_task.name] = skipped_task }
            next
          end
        end

        # Skip if fail-fast is enabled and any task has already failed
        if @fail_fast && @completed_tasks.values.any?(&:failed?)
          skipped_task = Task.new(
            name: task_def.name,
            command: task_def.command,
            parent: task_def.parent,
            dependencies: task_def.depends_on,
            is_autocorrect: task_def.is_autocorrect
          )
          skipped_task.mark_skipped(reason: "Skipped due to fail-fast")
          @formatter.start_task(skipped_task)
          @formatter.complete_task(skipped_task)
          @mutex.synchronize { @completed_tasks[skipped_task.name] = skipped_task }
          trigger_dependent_tasks(skipped_task, all_tasks, all_threads, threads_mutex)
          next
        end

        # Run the dependent task in a new thread
        thread = Thread.new do
          dependent_task = execute_task(task_def)
          Thread.current[:task] = dependent_task
          @mutex.synchronize { @completed_tasks[dependent_task.name] = dependent_task }

          # Recursively trigger tasks that depend on this one
          trigger_dependent_tasks(dependent_task, all_tasks, all_threads, threads_mutex)
          dependent_task
        end

        threads_mutex.synchronize { all_threads << thread }
      end
    end
  end
end
