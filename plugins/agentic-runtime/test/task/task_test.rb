# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/task/task'
require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/asset/catalog'
require_relative '../../lib/agentic_runtime/task/workspace'

class TestTask < Minitest::Test
  def test_create_a_task
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

      assert_equal task_id, task.id
      assert_equal 'created', task.progress.task_status
      assert_equal '01-inspect', task.progress.next_step_name
      assert_equal [['task.created', { 'task' => '20261005-example' }],
                    ['workflow.created', { 'catalog' => 'release-review' }]],
                   task.release_events.map { |event| [event.name, event.attributes] }
    end
  end

  def test_close_a_task
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
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')
      task = AgenticRuntime::Task::Task.create(
        id: task_id, workflow: catalog.find('release-review'),
        root: project, assets: AgenticRuntime::Asset::ProjectAssets.new(root: project)
      )
      task.plan.advance
      task.plan.current_step.complete
      before_close = task.progress

      task.close

      assert_equal 'closed', task.progress.task_status
      assert_equal 'created', before_close.task_status
      assert_equal ['task.closed', { 'task' => '20261005-example' }],
                   task.release_events.map { |event| [event.name, event.attributes] }.last
    end
  end

  def test_close_a_task_with_an_unfinished_plan
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
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')
      task = AgenticRuntime::Task::Task.create(
        id: task_id, workflow: catalog.find('release-review'),
        root: project, assets: AgenticRuntime::Asset::ProjectAssets.new(root: project)
      )
      task.plan.advance

      task.close

      assert_equal 'closed', task.progress.task_status
      assert_nil task.progress.current_step_name
      assert_equal 'cancelled', task.plan.steps.find { |step| step.name == '01-inspect' }.status
      assert_equal [['step.cancelled', { 'step' => '01-inspect' }], ['task.closed', { 'task' => '20261005-example' }]],
                   task.release_events.map { |event| [event.name, event.attributes] }.last(2)
    end
  end
end
