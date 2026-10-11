# frozen_string_literal: true

require_relative '../helper'

class TestTaskProgress < Minitest::Test
  include Helper

  %w[claude codex cursor].each do |runtime|
    define_method("test_task_progress_step_by_step_at_#{runtime}") do
      Dir.mktmpdir('agentic-runtime-') do |project|
        session_id = "stages-#{runtime}-session"
        env = session_env(runtime, session_id)
        workflows = File.join(project, '.agents/workflows')
        FileUtils.mkdir_p(workflows)
        File.write(File.join(workflows, 'simple-flow.yaml'), <<~YAML)
          name: simple-flow
          description: 条件を持たない二つのステップを進める
          steps:
            - name: 01-first
              description: 最初の仕事をする
            - name: 02-last
              description: 最後の仕事をする
        YAML

        created = run_cli(project, 'task create example --workflow simple-flow', env: env)
        task_id = created.body.fetch('task')
        workspace_path = File.join(project, 'workspace', task_id[0, 4], task_id[0, 6], task_id)
        assert_equal 0, created.code
        assert_match(/\A\d{8}-example\z/, task_id)
        assert_equal 'created', created.body.fetch('task_status')

        first = run_stop(project, runtime, session_id: session_id)
        assert_instruction first, runtime, '最初の仕事をする'
        assert_no_change run_stop(project, runtime, session_id: session_id), runtime

        completed = run_cli(project, "step complete #{task_id} 01-first", env: env)
        assert_equal 'completed', completed.body.fetch('step_status')
        assert_equal '02-last', completed.body.fetch('next_step')

        last = run_stop(project, runtime, session_id: session_id)
        assert_instruction last, runtime, '最後の仕事をする'

        completed = run_cli(project, "step complete #{task_id} 02-last", env: env)
        assert_equal 'completed', completed.body.fetch('step_status')
        assert_equal 'created', completed.body.fetch('task_status')
        assert_nil completed.body.fetch('next_step')

        closed = run_stop(project, runtime, session_id: session_id)
        assert_instruction closed, runtime, "タスク #{task_id} をクローズした。"
        assert_equal "closed\n", File.read(File.join(workspace_path, 'state'))
      end
    end
  end
end
