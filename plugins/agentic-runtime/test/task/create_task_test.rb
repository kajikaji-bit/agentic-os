# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/task/create_task'
require_relative '../../lib/agentic_runtime/asset/catalog'
require_relative '../../lib/agentic_runtime/task/workspace'
require_relative '../../lib/agentic_runtime/assignment/assignees'
require_relative '../../lib/agentic_runtime/assignment/session'

class TestCreateTask < Minitest::Test
  def test_task_creation_prepares_a_working_directory_and_assigns_the_session
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'briefing.yaml'), <<~YAML)
        name: release-review
        description: 公開前に変更内容を確認する
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

      today = Time.now.getlocal('+09:00').strftime('%Y%m%d')
      reloaded = AgenticRuntime::Task::Workspace.new(root: project)
      assert_equal AgenticRuntime::Task::TaskId.parse("#{today}-example"), task.id
      assert File.directory?(File.join(project, 'workspace', today[0, 4], today[0, 6], "#{today}-example"))
      assert_equal 'created', reloaded.find(task.id).progress.task_status
      assert_equal task.id,
                   AgenticRuntime::Assignment::Assignees.new(root: project).find_by(session: assignee).task_id
    end
  end
end
