# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/step/step_directory'
require_relative '../../lib/agentic_runtime/asset/catalog'
require_relative '../../lib/agentic_runtime/task/workspace'
require_relative '../../lib/agentic_runtime/assignment/assignees'
require_relative '../../lib/agentic_runtime/assignment/session'
require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/task/create_task'

class TestStepDirectory < Minitest::Test
  def test_retrieve_the_step_instruction_from_the_saved_workflow
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      rules = File.join(project, '.agents/rules')
      guide = File.join(project, 'wiki/work-guide.md')
      policy = File.join(project, 'wiki/review-policy.md')
      summarize = File.join(project, '.agents/skills/writing/SKILL.md')
      cite_sources = File.join(project, '.agents/skills/cite-sources/SKILL.md')
      reviewer = File.join(project, '.agents/agents/review/lead.md')
      FileUtils.mkdir_p(workflows)
      FileUtils.mkdir_p(rules)
      FileUtils.mkdir_p(File.dirname(guide))
      FileUtils.mkdir_p(File.dirname(summarize))
      FileUtils.mkdir_p(File.dirname(cite_sources))
      FileUtils.mkdir_p(File.dirname(reviewer))
      File.write(guide, '確認は公開する変更点から始める')
      File.write(policy, '指摘は変更点ごとに一つずつ書く')
      File.write(summarize, <<~MARKDOWN)
        ---
        name: summarize
        ---
        結論を先に書く
      MARKDOWN
      File.write(cite_sources, <<~MARKDOWN)
        ---
        name: cite-sources
        ---
        根拠の場所を添える
      MARKDOWN
      File.write(reviewer, <<~MARKDOWN)
        ---
        name: reviewer
        description: 公開前の確認を担う
        ---
        変更点ごとに公開してよい理由を書く
      MARKDOWN
      File.write(File.join(workflows, 'briefing.yaml'), <<~YAML)
        name: release-review
        description: 公開前に変更内容を確認する
        steps:
          - name: 01-inspect
            description: 公開する変更点を確認する
            artifacts:
              - notes.md
          - name: 02-summarize
            description: 確認した結果をまとめる
            read:
              - wiki/work-guide.md
              - 01-inspect/notes.md
            using:
              - summarize
            rules:
              - review-style
            agent: reviewer
      YAML
      File.write(File.join(rules, 'review-style.md'), <<~MARKDOWN)
        ---
        name: review-style
        using:
          - summarize
          - cite-sources
        read:
          - wiki/work-guide.md
          - wiki/review-policy.md
        ---
        まとめは結論から書く。
      MARKDOWN

      catalog = AgenticRuntime::Asset::Catalog.new(root: project)
      workspace = AgenticRuntime::Task::Workspace.new(root: project)
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      assignee = AgenticRuntime::Assignment::Session.from(runtime: 'codex', id: 'review-session')
      create_task = AgenticRuntime::Task::CreateTask.new(
        root: project, workspace: workspace, catalog: catalog, assets: assets,
        assignees: AgenticRuntime::Assignment::Assignees.new(root: project)
      )
      task = create_task.create(name: 'example', workflow_name: 'release-review', session: assignee)
      FileUtils.rm_rf(workflows)
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_id: task.id,
                                                          step_name: '02-summarize')

      directive = directory.directive

      assert_includes directive.body, '確認した結果をまとめる'
      refute_includes directive.body, '公開する変更点を確認する'
      assert_includes directive.body, AgenticRuntime::WorkspacePath.for(root: project, task_id: task.id).value
      assert_includes directive.body, 'まとめは結論から書く。'
      assert_includes directive.body, '公開前の確認を担う'
      assert_includes directive.body, '変更点ごとに公開してよい理由を書く'
      assert_equal 1, directive.body.scan(summarize).size
      assert_includes directive.body, cite_sources
      assert_equal 1, directive.body.scan(guide).size
      assert_includes directive.body, policy
      assert_includes directive.body, '01-inspect/notes.md'
      refute_includes directive.body,
                      File.join(AgenticRuntime::WorkspacePath.for(root: project, task_id: task.id).value,
                                '01-inspect/notes.md')
      assert_includes directive.body, "agentic-runtime step complete #{task.id} 02-summarize"
    end
  end

  def test_retrieve_the_step_instruction_that_requests_an_approval
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'briefing.yaml'), <<~YAML)
        name: release-review
        description: 公開前に変更内容を確認する
        steps:
          - name: 01-inspect
            description: 公開する変更点を確認する
            approval: required
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
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_id: task.id, step_name: '01-inspect')

      directive = directory.directive

      assert_includes directive.body, '## 承認を依頼する'
    end
  end

  def test_retrieve_the_step_artifacts
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      step_path = File.join(project, 'workspace/2026/202610/20261005-example/01-inspect')
      other_step_path = File.join(project, 'workspace/2026/202610/20261005-example/02-summarize')
      FileUtils.mkdir_p(step_path)
      FileUtils.mkdir_p(other_step_path)
      File.write(File.join(other_step_path, 'result.md'), '別のステップの結果')
      File.write(File.join(project, 'result.md'), 'プロジェクト直下の結果')
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_id: task_id, step_name: '01-inspect')

      assert_empty directory.artifacts

      File.write(File.join(step_path, 'result.md'), '確認結果')
      artifacts = directory.artifacts
      assert_equal ['result.md'], artifacts

      File.write(File.join(step_path, 'notes.md'), '確認の記録')

      assert_equal %w[notes.md result.md], directory.artifacts
      assert_equal ['result.md'], artifacts
    end
  end

  def test_retrieve_the_step_checklists
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      checks = File.join(project, '.agents/checks')
      step_checks = File.join(project, 'workspace/2026/202610/20261005-example/01-inspect/checks')
      FileUtils.mkdir_p(checks)
      File.write(File.join(checks, 'writing-policy.md'), <<~MARKDOWN)
        - [ ] 本文が日本語で書かれている
        - [ ] 同じ対象の呼び方が揃っている
      MARKDOWN
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_id: task_id, step_name: '01-inspect')

      assert_empty directory.checklists

      FileUtils.mkdir_p(step_checks)
      partially_checked = <<~MARKDOWN
        - [x] 本文が日本語で書かれている
        - [ ] 同じ対象の呼び方が揃っている
      MARKDOWN
      File.write(File.join(step_checks, 'writing-policy.md'), partially_checked)
      checklists = directory.checklists
      assert_equal ['writing-policy'], checklists.keys
      assert_equal partially_checked, checklists.fetch('writing-policy').body
      refute_predicate checklists.fetch('writing-policy'), :checked?

      File.write(File.join(step_checks, 'writing-policy.md'), <<~MARKDOWN)
        - [x] 本文が日本語で書かれている
        - [x] 同じ対象の呼び方が揃っている
      MARKDOWN

      assert_predicate directory.checklists.fetch('writing-policy'), :checked?
      refute_predicate checklists.fetch('writing-policy'), :checked?
    end
  end
end
