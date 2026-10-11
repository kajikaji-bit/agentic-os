# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'

require_relative '../lib/agentic_runtime/workspace_path'

class TestWorkspacePath < Minitest::Test
  def test_place_the_workspace_under_the_year_and_the_month_of_the_task_id
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      task_id = AgenticRuntime::Task::TaskId.parse('20261005-example')

      path = AgenticRuntime::WorkspacePath.for(root: project, task_id: task_id)

      assert_equal File.join(project, 'workspace/2026/202610/20261005-example'), path.value
      assert_equal task_id, path.task_id
    end
  end
end
