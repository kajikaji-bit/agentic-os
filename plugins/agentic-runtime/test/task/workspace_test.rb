# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'tmpdir'
require 'yaml'

require_relative '../../lib/agentic_runtime/task/workspace'
require_relative '../../lib/agentic_runtime/assignment/assignees'
require_relative '../../lib/agentic_runtime/asset/catalog'
require_relative '../../lib/agentic_runtime/task/task'
require_relative '../../lib/agentic_runtime/assignment/session'
require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/task/create_task'

class TestWorkspace < Minitest::Test
  def test_save_a_copy_of_the_task_workflow
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
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')
      task = AgenticRuntime::Task::Task.create(
        id: task_id, workflow: catalog.find('release-review'),
        root: project, assets: AgenticRuntime::Asset::ProjectAssets.new(root: project)
      )

      workspace.save(task)

      saved = File.read(File.join(project, 'workspace/2026/202610/20261005-example/workflow.yaml'))
      assert_equal YAML.safe_load(workflow_yaml), YAML.safe_load(saved)
    end
  end

  def test_retrieve_the_saved_task_workflow
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
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')
      task = AgenticRuntime::Task::Task.create(
        id: task_id, workflow: catalog.find('release-review'),
        root: project, assets: AgenticRuntime::Asset::ProjectAssets.new(root: project)
      )
      workspace.save(task)
      FileUtils.rm_rf(workflows)

      saved = AgenticRuntime::Task::Workspace.new(root: project).find(task_id).plan.workflow

      assert_equal 'release-review', saved.name
      assert_equal ['01-inspect', '02-summarize'], saved.steps.map(&:name)
      assert_equal ['公開する変更点を確認する', '確認した結果をまとめる'], saved.steps.map(&:description)
    end
  end

  def test_save_a_task_with_a_completed_step
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
      task.plan.current_step.complete

      workspace.save(task)

      saved = AgenticRuntime::Task::Workspace.new(root: project).find(task.id)
      completed_step = saved.plan.steps.find { |step| step.name == '01-inspect' }
      assert_equal 'completed', completed_step.status
      assert_nil saved.progress.current_step_name
      assert_equal '02-summarize', saved.progress.next_step_name
    end
  end

  def test_log_the_events_of_a_saved_task_once
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
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')
      task = AgenticRuntime::Task::Task.create(
        id: task_id, workflow: catalog.find('release-review'),
        root: project, assets: AgenticRuntime::Asset::ProjectAssets.new(root: project)
      )
      workspace.save(task)
      saved = AgenticRuntime::Task::Workspace.new(root: project).find(task_id)
      saved.plan.advance

      workspace.save(saved)
      workspace.save(saved)

      lines = File.readlines(File.join(project, 'workspace/2026/202610/20261005-example/log.jsonl')).map { |line|
        JSON.parse(line)
      }
      assert_equal %w[workspace.created task.created workflow.created step.started], lines.map { |line| line['event'] }
    end
  end

  def test_save_a_closed_task
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'briefing.yaml'), <<~YAML)
        name: release-review
        steps:
          - name: 01-inspect
            description: 公開する変更点を確認する
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
      task.plan.current_step.complete
      task.close

      workspace.save(task)

      saved = AgenticRuntime::Task::Workspace.new(root: project).find(task.id)
      assert_equal 'closed', saved.progress.task_status
      assert_equal %w[completed], saved.plan.steps.map(&:status)
    end
  end
end
