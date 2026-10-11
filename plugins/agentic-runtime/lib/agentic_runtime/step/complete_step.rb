# frozen_string_literal: true

require_relative 'step'

module AgenticRuntime
  module Step
    class CompleteStep
      def initialize(workspace:)
        @workspace = workspace
        freeze
      end

      def complete(task_id:, step_name:, approval_evidence: nil)
        task = @workspace.find(task_id)
        step = task.plan.current_step
        raise ArgumentError, '進行中のステップがありません' unless step
        raise ArgumentError, "進行中のステップは #{step.name} です" unless step.name == step_name

        step.complete(approval_evidence: approval_evidence)
        @workspace.save(task)
        @workspace.find(task_id)
      rescue Step::CompletionRejected
        @workspace.save(task)
        raise
      end
    end
  end
end
