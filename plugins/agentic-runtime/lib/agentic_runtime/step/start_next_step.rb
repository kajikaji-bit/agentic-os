# frozen_string_literal: true

module AgenticRuntime
  module Step
    class StartNextStep
      def initialize(workspace:, assets:, task:)
        @workspace = workspace
        @assets = assets
        @task = task
        freeze
      end

      def start
        raise ArgumentError, 'クローズ済みのタスクです' if @task.progress.task_status == 'closed'

        following = @task.plan.next_step
        raise ArgumentError, '開始できるステップがありません' unless following

        step_assets = @assets.for_step(definition: following)
        @task.plan.advance
        @workspace.save(@task, step_assets: step_assets)
        nil
      end
    end
  end
end
