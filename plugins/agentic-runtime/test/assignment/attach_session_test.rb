# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/assignment/attach_session'
require_relative '../../lib/agentic_runtime/asset/catalog'
require_relative '../../lib/agentic_runtime/task/workspace'
require_relative '../../lib/agentic_runtime/assignment/assignees'
require_relative '../../lib/agentic_runtime/assignment/session'
require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/task/create_task'

class TestAttachSession < Minitest::Test
  def test_attach_another_session_to_a_task_in_progress
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
      successor = AgenticRuntime::Assignment::Session.from(runtime: 'claude', id: 'successor-session')
      attach_session = AgenticRuntime::Assignment::AttachSession.new(
        workspace: workspace, assignees: AgenticRuntime::Assignment::Assignees.new(root: project)
      )

      assignment = attach_session.attach(task_id: task.id, session: successor)

      assert_equal task.id, assignment.task_id
      assert_equal successor, assignment.session
      assert_equal task.id,
                   AgenticRuntime::Assignment::Assignees.new(root: project).find_by(session: successor).task_id
      assert_nil AgenticRuntime::Assignment::Assignees.new(root: project).find_by(session: assignee)
    end
  end
end
