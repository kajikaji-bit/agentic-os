# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/assignment/assignment'
require_relative '../../lib/agentic_runtime/asset/catalog'
require_relative '../../lib/agentic_runtime/task/workspace'
require_relative '../../lib/agentic_runtime/assignment/session'
require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/task/task'

class TestAssignment < Minitest::Test
  def test_assign_a_session_to_a_task
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
      workflow = AgenticRuntime::Asset::Catalog.new(root: project).find('release-review')
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')
      task = AgenticRuntime::Task::Task.create(
        id: task_id, workflow: workflow,
        root: project, assets: AgenticRuntime::Asset::ProjectAssets.new(root: project)
      )
      session = AgenticRuntime::Assignment::Session.from(runtime: 'codex', id: 'review-session')

      assignment = AgenticRuntime::Assignment::Assignment.assign(task: task, session: session)

      assert_equal task_id, assignment.task_id
      assert_equal session, assignment.session
      assert_equal ['session.attached'], assignment.release_events.map(&:name)
      assert_equal [{ 'runtime' => 'codex', 'id' => 'review-session' }], assignment.release_events.map(&:attributes)
    end
  end

  def test_reject_assigning_a_session_to_a_closed_task
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
      workflow = AgenticRuntime::Asset::Catalog.new(root: project).find('release-review')
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')
      task = AgenticRuntime::Task::Task.create(
        id: task_id, workflow: workflow,
        root: project, assets: AgenticRuntime::Asset::ProjectAssets.new(root: project)
      )
      task.close
      session = AgenticRuntime::Assignment::Session.from(runtime: 'codex', id: 'review-session')

      assert_raises(ArgumentError) { AgenticRuntime::Assignment::Assignment.assign(task: task, session: session) }
    end
  end
end
