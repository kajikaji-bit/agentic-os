# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require_relative '../event'
require_relative '../workspace_log'
require_relative '../workspace_path'
require_relative 'task'
require_relative 'task_id'
require_relative '../asset/workflow'
require_relative 'plan'
require_relative '../step/step'
require_relative '../step/step_directory'
require_relative '../asset/project_assets'

module AgenticRuntime
  module Task
    class Workspace
      def initialize(root:)
        @root = File.expand_path(root).freeze
        @assets = Asset::ProjectAssets.new(root: @root)
        freeze
      end

      def paths
        directories = Dir.glob(File.join(@root, 'workspace', '*', '*', '*')).select { |path| File.directory?(path) }
        directories.filter_map { |directory| placed_path(directory) }.sort_by(&:value)
      end

      def find(task_id)
        path = WorkspacePath.for(root: @root, task_id: task_id).value
        raise ArgumentError, "タスクがありません: #{task_id}" unless Dir.exist?(path)

        workflow = Asset::Workflow.parse(File.read(File.join(path, 'workflow.yaml')))
        definitions = workflow.steps.to_h { |definition| [definition.name, definition] }

        events = WorkspaceLog.new(root: @root, task_id: task_id).events
        statuses = events.each_with_object({}) do |event, found|
          next unless %w[step.started step.completed step.cancelled].include?(event.name)

          found[event.attributes.fetch('step')] = event.name.delete_prefix('step.')
        end

        steps = statuses.map do |step_name, status|
          definition = definitions[step_name]
          raise ArgumentError, "保存したステップが定義にありません: #{step_name}" unless definition

          directory = Step::StepDirectory.new(root: @root, task_id: task_id, step_name: step_name)
          Step::Step.restore(task_id: task_id, definition: definition, directory: directory, assets: @assets,
                             status: status)
        end

        plan = Plan.new(task_id: task_id, workflow: workflow, root: @root, assets: @assets, steps: steps)
        status = events.any? { |event| event.name == 'task.closed' } ? 'closed' : 'created'
        Task.restore(id: task_id, plan: plan, status: status)
      end

      def save(task, step_assets: nil)
        path = WorkspacePath.for(root: @root, task_id: task.id).value
        raise ArgumentError, "同じタスク ID のタスクがあります: #{task.id}" if task.new_record? && Dir.exist?(path)

        events = task.release_events

        if task.new_record?
          FileUtils.mkdir_p(File.dirname(path))
          Dir.mkdir(path)
          File.write(File.join(path, 'task.md'), "# #{task.id}\n")
          File.write(File.join(path, 'workflow.yaml'), task.plan.workflow.source)
          events = [Event.new(name: 'workspace.created', attributes: { 'task' => task.id.to_s }), *events]
        end

        if step_assets && step_assets.checklists.any?
          step = task.plan.current_step
          raise ArgumentError, '開始したステップがありません' unless step

          step_path = File.join(path, step.name)
          staged = Dir.mktmpdir(".#{step.name}-", path)
          checks = File.join(staged, 'checks')
          FileUtils.mkdir_p(checks)
          step_assets.checklists.each do |checklist|
            File.write(File.join(checks, "#{checklist.name}.md"), checklist.body)
          end
        end

        WorkspaceLog.new(root: @root, task_id: task.id).append(events)
        task.clear_events

        if staged
          FileUtils.rm_rf(step_path)
          File.rename(staged, step_path)
        end

        progress = task.progress
        File.write(File.join(path, 'current_step'), "#{progress.current_step_name}\n")
        File.write(File.join(path, 'state'), "#{progress.task_status}\n")
        nil
      ensure
        FileUtils.rm_rf(staged) if staged
      end

      private

      def placed_path(directory)
        path = WorkspacePath.for(root: @root, task_id: TaskId.parse(File.basename(directory)))
        path if path.value == directory
      rescue ArgumentError
        nil
      end
    end
  end
end
