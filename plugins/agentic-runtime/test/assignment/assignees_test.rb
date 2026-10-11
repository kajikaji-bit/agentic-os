# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/assignment/assignees'
require_relative '../../lib/agentic_runtime/asset/catalog'
require_relative '../../lib/agentic_runtime/task/workspace'
require_relative '../../lib/agentic_runtime/assignment/session'
require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/task/create_task'

class TestAssignees < Minitest::Test
  def test_find_the_assignment_of_a_session
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      FileUtils.mkdir_p(workflows)
      workflow_yaml = <<~YAML
        name: release-review
        description: 公開前に変更内容を確認する
        steps:
          - name: 01-inspect
            description: 公開する変更点を確認する
          - name: 02-summarize
            description: 確認した結果をまとめる
      YAML
      File.write(File.join(workflows, 'briefing.yaml'), workflow_yaml)

      catalog = AgenticRuntime::Asset::Catalog.new(root: project)
      workspace = AgenticRuntime::Task::Workspace.new(root: project)
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      create_task = AgenticRuntime::Task::CreateTask.new(
        root: project, workspace: workspace, catalog: catalog, assets: assets,
        assignees: AgenticRuntime::Assignment::Assignees.new(root: project)
      )
      other_session = AgenticRuntime::Assignment::Session.from(runtime: 'cursor', id: 'review-session')
      assignee = AgenticRuntime::Assignment::Session.from(runtime: 'codex', id: 'review-session')
      create_task.create(name: 'another-task', workflow_name: 'release-review',
                         session: other_session)
      task = create_task.create(name: 'example', workflow_name: 'release-review', session: assignee)

      assigned = AgenticRuntime::Assignment::Assignees.new(root: project).find_by(session: assignee)

      assert_equal task.id, assigned.task_id
      assert_equal assignee, assigned.session
      last_line = JSON.parse(File.readlines(File.join(
                                              AgenticRuntime::WorkspacePath.for(root: project,
                                                                                task_id: task.id).value, 'log.jsonl'
                                            )).last)
      assert_equal({ 'event' => 'session.attached', 'runtime' => 'codex', 'id' => 'review-session' },
                   last_line.except('at'))
    end
  end
end
