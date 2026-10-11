# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/asset/catalog'
require_relative '../../lib/agentic_runtime/task/workspace'
require_relative '../../lib/agentic_runtime/task/task'
require_relative '../../lib/agentic_runtime/asset/project_assets'

class TestProgress < Minitest::Test
  def test_all_steps_are_completed
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'briefing.yaml'), <<~YAML)
        name: release-review
        steps:
          - name: 01-inspect
            description: 公開する変更点を確認する
          - name: 02-summarize
            description: 確認した結果をまとめる
      YAML

      catalog = AgenticRuntime::Asset::Catalog.new(root: project)
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')
      task = AgenticRuntime::Task::Task.create(
        id: task_id, workflow: catalog.find('release-review'),
        root: project, assets: AgenticRuntime::Asset::ProjectAssets.new(root: project)
      )
      task.plan.advance
      task.plan.current_step.complete
      task.plan.advance
      before_completion = task.progress

      task.plan.current_step.complete

      progress = task.progress
      assert progress.completed?
      assert_nil progress.current_step_name
      assert_nil progress.next_step_name
      assert_equal 'created', progress.task_status
      refute before_completion.completed?
      assert_equal '02-summarize', before_completion.current_step_name
    end
  end
end
