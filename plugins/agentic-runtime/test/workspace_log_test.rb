# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'time'
require 'tmpdir'

require_relative '../lib/agentic_runtime/workspace_log'
require_relative '../lib/agentic_runtime/event'

class TestWorkspaceLog < Minitest::Test
  def test_append_events_as_lines_with_the_recorded_time
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      FileUtils.mkdir_p(File.join(project, 'workspace/2026/202610/20261005-example'))
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')
      log = AgenticRuntime::WorkspaceLog.new(root: project, task_id: task_id)
      started_at = Time.now.floor

      log.append(AgenticRuntime::Event.new(name: 'task.created', attributes: { 'task' => '20261005-example' }))
      log.append([AgenticRuntime::Event.new(name: 'step.started', attributes: { 'step' => '01-inspect' })])

      lines = File.readlines(File.join(project, 'workspace/2026/202610/20261005-example/log.jsonl')).map { |line|
        JSON.parse(line)
      }
      assert_equal [%w[at event task], %w[at event step]], lines.map(&:keys)
      assert_equal [{ 'event' => 'task.created', 'task' => '20261005-example' },
                    { 'event' => 'step.started', 'step' => '01-inspect' }], lines.map { |line| line.except('at') }
      lines.each do |line|
        assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+09:00\z/, line['at'])
        assert_operator Time.iso8601(line['at']), :>=, started_at
      end
      events = AgenticRuntime::WorkspaceLog.new(root: project, task_id: task_id).events
      assert_equal %w[task.created step.started], events.map(&:name)
      assert_equal [{ 'task' => '20261005-example' }, { 'step' => '01-inspect' }], events.map(&:attributes)
    end
  end
end
