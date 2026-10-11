# frozen_string_literal: true

require_relative '../step/step'
require_relative '../step/step_directory'

module AgenticRuntime
  module Task
    class Plan
      attr_reader :workflow

      def initialize(task_id:, workflow:, root:, assets:, steps: [])
        @task_id = task_id
        @workflow = workflow
        @root = File.expand_path(root).freeze
        @assets = assets
        @steps = steps.dup
      end

      def current_step
        @steps.find { |step| step.status == 'started' }
      end

      def next_step
        return nil if current_step

        completed_names = @steps.map(&:name)
        @workflow.steps.reject { |definition| completed_names.include?(definition.name) }.first
      end

      def steps
        @steps.dup.freeze
      end

      def advance
        raise ArgumentError, '進行中のステップがあります' if current_step

        following = next_step
        raise ArgumentError, '次のステップがありません' unless following

        directory = Step::StepDirectory.new(root: @root, task_id: @task_id, step_name: following.name)
        @steps << Step::Step.start(task_id: @task_id, definition: following, directory: directory, assets: @assets)
        nil
      end
    end
  end
end
