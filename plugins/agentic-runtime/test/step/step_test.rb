# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/step/step'
require_relative '../../lib/agentic_runtime/step/step_directory'
require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/asset/catalog'
require_relative '../../lib/agentic_runtime/task/workspace'
require_relative '../../lib/agentic_runtime/assignment/assignees'
require_relative '../../lib/agentic_runtime/assignment/session'
require_relative '../../lib/agentic_runtime/task/create_task'

class TestStep < Minitest::Test
  def test_start_a_step
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

      definition = catalog.find('release-review').steps.first
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_id: task.id, step_name: '01-inspect')
      step = AgenticRuntime::Step::Step.start(
        task_id: task.id, definition: definition, directory: directory, assets: assets
      )

      assert_equal '01-inspect', step.name
      assert_equal 'started', step.status
      assert_equal [['step.started', { 'step' => '01-inspect' }]],
                   step.release_events.map { |event| [event.name, event.attributes] }
    end
  end

  def test_complete_a_step
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'review.yaml'), <<~YAML)
        name: review
        steps:
          - name: 01-inspect
            description: 変更点を確認する
            artifacts:
              - result.md
              - notes.md
            checks:
              - writing-policy
            rules:
              - ruby-readability
            approval: required
      YAML
      rules = File.join(project, '.agents/rules')
      FileUtils.mkdir_p(rules)
      File.write(File.join(rules, 'ruby-readability.md'), <<~MARKDOWN)
        ---
        name: ruby-readability
        checks:
          - naming-policy
        ---
        条件は肯定文で書く。
      MARKDOWN
      workflow = AgenticRuntime::Asset::Catalog.new(root: project).find('review')
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      step_path = File.join(project, 'workspace/2026/202610/20261005-example/01-inspect')
      FileUtils.mkdir_p(File.join(step_path, 'checks'))
      File.write(File.join(step_path, 'result.md'), '確認結果')
      File.write(File.join(step_path, 'notes.md'), '確認の記録')
      File.write(File.join(step_path, 'checks/writing-policy.md'), <<~MARKDOWN)
        - [x] 本文が日本語で書かれている
        - [x] 同じ対象の呼び方が揃っている
      MARKDOWN
      File.write(File.join(step_path, 'checks/naming-policy.md'), <<~MARKDOWN)
        - [x] 1 語で足りる名前は 1 語にしている
      MARKDOWN
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_id: task_id, step_name: '01-inspect')
      step = AgenticRuntime::Step::Step.start(
        task_id: task_id, definition: workflow.steps.first, directory: directory, assets: assets
      )

      step.complete(approval_evidence: '承認します')

      assert_equal 'completed', step.status
      assert_equal [['report.approved', { 'step' => '01-inspect', 'evidence' => '承認します' }],
                    ['step.completed', { 'step' => '01-inspect' }]],
                   step.release_events.map { |event| [event.name, event.attributes] }.last(2)
    end
  end

  def test_do_not_complete_a_step_without_the_approval_evidence
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'review.yaml'), <<~YAML)
        name: review
        steps:
          - name: 01-inspect
            description: 変更点を確認する
            approval: required
      YAML
      workflow = AgenticRuntime::Asset::Catalog.new(root: project).find('review')
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_id: task_id, step_name: '01-inspect')
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      step = AgenticRuntime::Step::Step.start(
        task_id: task_id, definition: workflow.steps.first, directory: directory, assets: assets
      )

      assert_raises(AgenticRuntime::Step::Step::CompletionRejected) { step.complete }

      assert_equal 'started', step.status
      assert_equal %w[step.started completion.rejected], step.release_events.map(&:name)
      unmet = [{ condition: 'approval', correction: '承認者本人の発言を指定する' }]
      assert_equal({ 'step' => '01-inspect', 'unmet' => unmet }, step.release_events.last.attributes)
    end
  end

  def test_do_not_complete_a_step_with_missing_artifacts
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'review.yaml'), <<~YAML)
        name: review
        steps:
          - name: 01-inspect
            description: 変更点を確認する
            artifacts:
              - result.md
              - notes.md
      YAML
      workflow = AgenticRuntime::Asset::Catalog.new(root: project).find('review')
      step_path = File.join(project, 'workspace/2026/202610/20261005-example/01-inspect')
      FileUtils.mkdir_p(step_path)
      File.write(File.join(step_path, 'result.md'), '確認結果')
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_id: task_id, step_name: '01-inspect')
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      step = AgenticRuntime::Step::Step.start(
        task_id: task_id, definition: workflow.steps.first, directory: directory, assets: assets
      )

      assert_raises(AgenticRuntime::Step::Step::CompletionRejected) { step.complete }

      assert_equal 'started', step.status
      assert_equal %w[step.started completion.rejected], step.release_events.map(&:name)
      unmet = [{ condition: 'artifact:notes.md', correction: '成果物 notes.md を作成する' }]
      assert_equal({ 'step' => '01-inspect', 'unmet' => unmet }, step.release_events.last.attributes)
    end
  end

  def test_do_not_complete_a_step_with_unfinished_checks
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'review.yaml'), <<~YAML)
        name: review
        steps:
          - name: 01-inspect
            description: 変更点を確認する
            artifacts:
              - result.md
              - notes.md
            checks:
              - writing-policy
              - uses-terminology
      YAML
      workflow = AgenticRuntime::Asset::Catalog.new(root: project).find('review')
      step_path = File.join(project, 'workspace/2026/202610/20261005-example/01-inspect')
      FileUtils.mkdir_p(File.join(step_path, 'checks'))
      File.write(File.join(step_path, 'result.md'), '確認結果')
      File.write(File.join(step_path, 'notes.md'), '確認の記録')
      File.write(File.join(step_path, 'checks/writing-policy.md'), <<~MARKDOWN)
        - [x] 本文が日本語で書かれている
        - [x] 同じ対象の呼び方が揃っている
      MARKDOWN
      File.write(File.join(step_path, 'checks/uses-terminology.md'), <<~MARKDOWN)
        - [x] 用語集にない言葉が使われていない
        - [ ] 用語集の言葉を用語集が定めた意味で使っている
      MARKDOWN
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_id: task_id, step_name: '01-inspect')
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      step = AgenticRuntime::Step::Step.start(
        task_id: task_id, definition: workflow.steps.first, directory: directory, assets: assets
      )

      assert_raises(AgenticRuntime::Step::Step::CompletionRejected) { step.complete }

      assert_equal 'started', step.status
      assert_equal %w[step.started completion.rejected], step.release_events.map(&:name)
      unmet = [{ condition: 'check:uses-terminology', correction: 'Checklist uses-terminology の未チェックの項目を解いてチェックを付ける' }]
      assert_equal({ 'step' => '01-inspect', 'unmet' => unmet }, step.release_events.last.attributes)
    end
  end

  def test_do_not_complete_a_step_with_unfinished_rule_checks
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      rules = File.join(project, '.agents/rules')
      FileUtils.mkdir_p(workflows)
      FileUtils.mkdir_p(rules)
      File.write(File.join(workflows, 'review.yaml'), <<~YAML)
        name: review
        steps:
          - name: 01-inspect
            description: 変更点を確認する
            rules:
              - ruby-readability
      YAML
      File.write(File.join(rules, 'ruby-readability.md'), <<~MARKDOWN)
        ---
        name: ruby-readability
        checks:
          - naming-policy
        ---
        条件は肯定文で書く。
      MARKDOWN
      workflow = AgenticRuntime::Asset::Catalog.new(root: project).find('review')
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      step_checks = File.join(project, 'workspace/2026/202610/20261005-example/01-inspect/checks')
      FileUtils.mkdir_p(step_checks)
      File.write(File.join(step_checks, 'naming-policy.md'), <<~MARKDOWN)
        - [ ] 1 語で足りる名前は 1 語にしている
      MARKDOWN
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_id: task_id, step_name: '01-inspect')
      step = AgenticRuntime::Step::Step.start(
        task_id: task_id, definition: workflow.steps.first, directory: directory, assets: assets
      )

      assert_raises(AgenticRuntime::Step::Step::CompletionRejected) { step.complete }

      assert_equal 'started', step.status
      assert_equal %w[step.started completion.rejected], step.release_events.map(&:name)
      unmet = [{ condition: 'check:naming-policy', correction: 'Checklist naming-policy の未チェックの項目を解いてチェックを付ける' }]
      assert_equal({ 'step' => '01-inspect', 'unmet' => unmet }, step.release_events.last.attributes)
    end
  end

  def test_cancel_a_step
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
      definition = catalog.find('release-review').steps.first
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_id: task.id, step_name: '01-inspect')
      step = AgenticRuntime::Step::Step.start(
        task_id: task.id, definition: definition, directory: directory, assets: assets
      )

      step.cancel

      assert_equal 'cancelled', step.status
      assert_equal ['step.cancelled', { 'step' => '01-inspect' }],
                   step.release_events.map { |event| [event.name, event.attributes] }.last
    end
  end

  def test_do_not_cancel_a_completed_step
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'review.yaml'), <<~YAML)
        name: review
        steps:
          - name: 01-inspect
            description: 変更点を確認する
      YAML
      workflow = AgenticRuntime::Asset::Catalog.new(root: project).find('review')
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')
      directory = AgenticRuntime::Step::StepDirectory.new(root: project, task_id: task_id, step_name: '01-inspect')
      step = AgenticRuntime::Step::Step.start(
        task_id: task_id, definition: workflow.steps.first, directory: directory, assets: assets
      )
      step.complete

      assert_raises(ArgumentError) { step.cancel }

      assert_equal 'completed', step.status
    end
  end
end
