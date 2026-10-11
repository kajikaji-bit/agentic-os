# frozen_string_literal: true

require 'minitest/autorun'

require_relative '../../lib/agentic_runtime/task/task_id'

class TestTaskId < Minitest::Test
  def test_generate_a_task_id_from_the_name_and_the_date_in_japan
    today = Time.now.getlocal('+09:00').strftime('%Y%m%d')

    task_id = AgenticRuntime::Task::TaskId.generate('workspace-by-date')

    assert_equal "#{today}-workspace-by-date", task_id.to_s
  end
end
