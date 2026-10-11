# frozen_string_literal: true

require_relative '../asset/workflow'
require_relative '../asset/checklist'
require_relative '../asset/knowledge'
require_relative '../asset/project_assets'
require_relative 'directive'
require_relative '../workspace_path'

module AgenticRuntime
  module Step
    class StepDirectory
      def initialize(root:, task_id:, step_name:)
        @root = File.expand_path(root).freeze
        @path = WorkspacePath.for(root: @root, task_id: task_id).value
        @task_id = task_id
        @step_name = step_name.dup.freeze
        freeze
      end

      def artifacts
        path = File.join(@path, @step_name)
        Dir.glob('**/*', File::FNM_DOTMATCH, base: path).select do |file|
          File.file?(File.join(path, file))
        end.sort.map(&:freeze).freeze
      end

      def checklists
        checks = File.join(@step_name, 'checks')
        files = Dir.glob('*.md', base: File.join(@path, checks)).sort
        files.map { |file| checklist(File.join(checks, file)) }.to_h { |checklist| [checklist.name, checklist] }.freeze
      end

      def directive
        definition = step_definition
        assets = Asset::ProjectAssets.new(root: @root)
        rules = assets.rules(definition: definition)
        Directive.new(task_id: @task_id, step_definition: definition, workspace_path: @path, rules: rules,
                      role: assets.role(definition: definition),
                      skills: assets.skills(definition: definition).map { |skill| File.join(@root, skill.path) },
                      reading_list: reading_list(definition.read + rules.flat_map(&:read)),
                      checklists: checklists.values)
      end

      private

      def step_definition
        workflow = Asset::Workflow.parse(File.read(File.join(@path, 'workflow.yaml')))
        definition = workflow.steps.find { |step| step.name == @step_name }
        raise ArgumentError, "ステップが見つかりません: #{@step_name}" unless definition

        definition
      end

      def reading_list(reading_items)
        reading_items.map do |reading_item|
          reading_item.is_a?(Asset::Knowledge) ? File.join(@root, reading_item.path) : reading_item.path
        end.uniq
      end

      def checklist(path)
        Asset::Checklist.from_markdown(File.read(File.join(@path, path)), path: path)
      end
    end
  end
end
