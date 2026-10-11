# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/task/continuation'
require_relative '../../lib/agentic_runtime/task/progress'
require_relative '../../lib/agentic_runtime/asset/catalog'
require_relative '../../lib/agentic_runtime/task/workspace'
require_relative '../../lib/agentic_runtime/assignment/assignees'
require_relative '../../lib/agentic_runtime/assignment/session'
require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/task/create_task'

class TestContinuation < Minitest::Test
  def test_decide_to_advance_when_no_step_is_in_progress_and_work_remains
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
      progress = AgenticRuntime::Task::Workspace.new(root: project).find(task.id).progress
      continuation = AgenticRuntime::Task::Continuation.new

      decision = continuation.decide(progress: progress)

      assert_equal :next, decision
      assert_nil AgenticRuntime::Task::Workspace.new(root: project).find(task.id).progress.current_step_name
    end
  end

  def test_decide_to_continue_the_step_in_progress
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
      task = workspace.find(task.id)
      task.plan.advance
      workspace.save(task)
      progress = AgenticRuntime::Task::Workspace.new(root: project).find(task.id).progress
      continuation = AgenticRuntime::Task::Continuation.new

      decision = continuation.decide(progress: progress)

      assert_equal :continue, decision
      assert_equal '01-inspect',
                   AgenticRuntime::Task::Workspace.new(root: project).find(task.id).progress.current_step_name
    end
  end

  def test_decide_done_when_no_work_remains
    progress = AgenticRuntime::Task::Progress.new(task_status: 'created', current_step_name: nil, next_step_name: nil)
    continuation = AgenticRuntime::Task::Continuation.new

    decision = continuation.decide(progress: progress)

    assert_equal :done, decision
  end
end
