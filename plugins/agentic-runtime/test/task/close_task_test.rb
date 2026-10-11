# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/task/close_task'
require_relative '../../lib/agentic_runtime/asset/catalog'
require_relative '../../lib/agentic_runtime/task/workspace'
require_relative '../../lib/agentic_runtime/assignment/assignees'
require_relative '../../lib/agentic_runtime/assignment/session'
require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/task/create_task'

class TestCloseTask < Minitest::Test
  def test_close_a_task_in_progress
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
      workspace = AgenticRuntime::Task::Workspace.new(root: project)
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      assignee = AgenticRuntime::Assignment::Session.from(runtime: 'codex', id: 'review-session')
      create_task = AgenticRuntime::Task::CreateTask.new(
        root: project, workspace: workspace, catalog: catalog, assets: assets,
        assignees: AgenticRuntime::Assignment::Assignees.new(root: project)
      )
      task = create_task.create(name: 'example', workflow_name: 'release-review', session: assignee)
      task.plan.advance
      workspace.save(task)
      close_task = AgenticRuntime::Task::CloseTask.new(workspace: workspace)

      closed = close_task.close(task_id: task.id)

      assert_equal 'closed', closed.progress.task_status
      assert_nil closed.progress.current_step_name
      saved = AgenticRuntime::Task::Workspace.new(root: project).find(task.id)
      assert_equal 'closed', saved.progress.task_status
      assert_equal 'cancelled', saved.plan.steps.find { |step| step.name == '01-inspect' }.status
    end
  end
end
