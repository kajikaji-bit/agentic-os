# frozen_string_literal: true

require_relative 'task'
require_relative 'task_id'
require_relative '../assignment/assignment'

module AgenticRuntime
  module Task
    class CreateTask
      def initialize(root:, workspace:, catalog:, assets:, assignees:)
        @root = File.expand_path(root).freeze
        @workspace = workspace
        @catalog = catalog
        @assets = assets
        @assignees = assignees
        freeze
      end

      def create(name:, workflow_name:, session:)
        task = Task.create(id: TaskId.generate(name), workflow: verified_workflow(workflow_name), root: @root,
                           assets: @assets)
        @workspace.save(task)
        @assignees.save(Assignment::Assignment.assign(task: task, session: session)) if session
        @workspace.find(task.id)
      end

      private

      def verified_workflow(workflow_name)
        workflow = @catalog.find(workflow_name)
        workflow.steps.each { |definition| @assets.for_step(definition: definition) }
        workflow
      end
    end
  end
end
