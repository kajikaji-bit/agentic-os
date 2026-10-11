# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative '../invalid_usage'
require_relative '../task/workspace'
require_relative '../task/task_id'
require_relative 'complete_step'
require_relative 'cancel_step'

module AgenticRuntime
  module Step
    class StepCommands
      def initialize(root:, stdout:)
        workspace = Task::Workspace.new(root: root)
        @complete_step = CompleteStep.new(workspace: workspace)
        @cancel_step = CancelStep.new(workspace: workspace)
        @stdout = stdout
        freeze
      end

      def complete(arguments)
        id, step, evidence = parameters(arguments)
        task = @complete_step.complete(task_id: Task::TaskId.parse(id), step_name: step, approval_evidence: evidence)
        progress = task.progress
        @stdout.puts(JSON.generate(
                       task: id, step: step, step_status: 'completed',
                       task_status: progress.task_status, next_step: progress.next_step_name
                     ))
        0
      end

      def cancel(arguments)
        id, step, *rest = arguments
        missing = []
        missing << 'タスク ID' unless id
        missing << 'ステップ名' unless step
        raise InvalidUsage, "足りない引数です: #{missing.join('、')}" if missing.any?
        raise InvalidUsage, "余分な引数です: #{rest.join(' ')}" if rest.any?

        task = @cancel_step.cancel(task_id: Task::TaskId.parse(id), step_name: step)
        progress = task.progress
        @stdout.puts(JSON.generate(
                       task: id, step: step, step_status: 'cancelled',
                       task_status: progress.task_status, next_step: progress.next_step_name
                     ))
        0
      end

      private

      def parameters(arguments)
        id, step, *values = arguments
        options = OptionParser.new.getopts(values, '', 'approval-evidence:')
        missing = []
        missing << 'タスク ID' unless id
        missing << 'ステップ名' unless step
        raise InvalidUsage, "足りない引数です: #{missing.join('、')}" if missing.any?
        raise InvalidUsage, "余分な引数です: #{values.join(' ')}" if values.any?

        [id, step, options['approval-evidence']]
      rescue OptionParser::InvalidOption => e
        raise InvalidUsage, "知らないオプションです: #{e.args.first}"
      rescue OptionParser::MissingArgument => e
        raise InvalidUsage, "オプションの値がありません: #{e.args.first}"
      end
    end
  end
end
