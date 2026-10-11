# frozen_string_literal: true

module AgenticRuntime
  module Step
    class CancelStep
      def initialize(workspace:)
        @workspace = workspace
        freeze
      end

      def cancel(task_id:, step_name:)
        task = @workspace.find(task_id)
        step = task.plan.current_step
        raise ArgumentError, '進行中のステップがありません' unless step
        raise ArgumentError, "進行中のステップは #{step.name} です" unless step.name == step_name

        step.cancel
        @workspace.save(task)
        @workspace.find(task_id)
      end
    end
  end
end
