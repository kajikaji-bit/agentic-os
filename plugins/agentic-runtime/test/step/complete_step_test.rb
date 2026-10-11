# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/step/complete_step'
require_relative '../../lib/agentic_runtime/asset/catalog'
require_relative '../../lib/agentic_runtime/task/workspace'
require_relative '../../lib/agentic_runtime/assignment/assignees'
require_relative '../../lib/agentic_runtime/assignment/session'
require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/task/create_task'

class TestCompleteStep < Minitest::Test
  def test_complete_a_step
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
      complete_step = AgenticRuntime::Step::CompleteStep.new(workspace: workspace)

      completed = complete_step.complete(task_id: task.id, step_name: '01-inspect')

      assert_equal task.id, completed.id
      assert_nil completed.progress.current_step_name
      assert_equal '02-summarize', completed.progress.next_step_name
      saved = AgenticRuntime::Task::Workspace.new(root: project).find(task.id)
      assert_equal 'completed', saved.plan.steps.find { |step| step.name == '01-inspect' }.status
    end
  end

  def test_cannot_complete_a_step_with_an_unmet_condition
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'briefing.yaml'), <<~YAML)
        name: release-review
        steps:
          - name: 01-inspect
            description: 公開する変更点を確認する
            artifacts:
              - result.md
            approval: required
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
      complete_step = AgenticRuntime::Step::CompleteStep.new(workspace: workspace)

      assert_raises(AgenticRuntime::Step::Step::CompletionRejected) do
        complete_step.complete(task_id: task.id, step_name: '01-inspect', approval_evidence: '承認します')
      end

      saved = AgenticRuntime::Task::Workspace.new(root: project).find(task.id)
      assert_equal 'started', saved.plan.steps.find { |step| step.name == '01-inspect' }.status
      lines = File.readlines(File.join(AgenticRuntime::WorkspacePath.for(root: project, task_id: task.id).value,
                                       'log.jsonl')).last(2)
      assert_equal [{ 'event' => 'report.approved', 'step' => '01-inspect', 'evidence' => '承認します' },
                    { 'event' => 'completion.rejected', 'step' => '01-inspect',
                      'unmet' => [{ 'condition' => 'artifact:result.md', 'correction' => '成果物 result.md を作成する' }] }],
                   lines.map { |line| JSON.parse(line).except('at') }
    end
  end

  def test_cannot_complete_an_unstarted_step
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
      complete_step = AgenticRuntime::Step::CompleteStep.new(workspace: workspace)

      assert_raises(ArgumentError) do
        complete_step.complete(task_id: task.id, step_name: '02-summarize')
      end

      saved = AgenticRuntime::Task::Workspace.new(root: project).find(task.id)
      assert_equal '01-inspect', saved.progress.current_step_name
      assert_equal 'started', saved.plan.current_step.status
      assert_nil saved.progress.next_step_name
    end
  end
end
