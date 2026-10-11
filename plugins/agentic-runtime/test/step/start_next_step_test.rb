# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/asset/catalog'
require_relative '../../lib/agentic_runtime/task/workspace'
require_relative '../../lib/agentic_runtime/assignment/assignees'
require_relative '../../lib/agentic_runtime/assignment/session'
require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/step/start_next_step'
require_relative '../../lib/agentic_runtime/task/create_task'

class TestStartNextStep < Minitest::Test
  def test_start_a_step_and_arrange_its_checklists
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      checks = File.join(project, '.agents/checks')
      rules = File.join(project, '.agents/rules')
      FileUtils.mkdir_p(workflows)
      FileUtils.mkdir_p(checks)
      FileUtils.mkdir_p(rules)
      File.write(File.join(workflows, 'review.yaml'), <<~YAML)
        name: review
        rules:
          - ruby-readability
        steps:
          - name: 01-inspect
            description: 変更点を確認する
            checks:
              - writing-policy
      YAML
      writing_policy = <<~MARKDOWN
        - [ ] 本文が日本語で書かれている
        - [ ] 同じ対象の呼び方が揃っている
      MARKDOWN
      File.write(File.join(checks, 'writing-policy.md'), writing_policy)
      naming_policy = <<~MARKDOWN
        - [ ] 1 語で足りる名前は 1 語にしている
      MARKDOWN
      File.write(File.join(checks, 'naming-policy.md'), naming_policy)
      File.write(File.join(rules, 'ruby-readability.md'), <<~MARKDOWN)
        ---
        name: ruby-readability
        checks:
          - naming-policy
        ---
        条件は肯定文で書く。
      MARKDOWN
      catalog = AgenticRuntime::Asset::Catalog.new(root: project)
      workspace = AgenticRuntime::Task::Workspace.new(root: project)
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      assignee = AgenticRuntime::Assignment::Session.from(runtime: 'codex', id: 'review-session')
      create_task = AgenticRuntime::Task::CreateTask.new(
        root: project, workspace: workspace, catalog: catalog, assets: assets,
        assignees: AgenticRuntime::Assignment::Assignees.new(root: project)
      )
      task = create_task.create(name: 'example', workflow_name: 'review', session: assignee)
      task = workspace.find(task.id)

      AgenticRuntime::Step::StartNextStep.new(workspace: workspace, assets: assets, task: task).start

      assert_equal '01-inspect', task.progress.current_step_name
      workspace_path = AgenticRuntime::WorkspacePath.for(root: project, task_id: task.id).value
      arranged = File.join(workspace_path, '01-inspect/checks')
      assert_equal writing_policy, File.read(File.join(arranged, 'writing-policy.md'))
      assert_equal naming_policy, File.read(File.join(arranged, 'naming-policy.md'))
      saved = AgenticRuntime::Task::Workspace.new(root: project).find(task.id)
      assert_equal '01-inspect', saved.progress.current_step_name
    end
  end
end
