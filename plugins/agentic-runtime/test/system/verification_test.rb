# frozen_string_literal: true

require_relative '../helper'

class TestVerification < Minitest::Test
  include Helper

  %w[claude codex cursor].each do |runtime|
    define_method("test_verification_before_step_completion_at_#{runtime}") do
      Dir.mktmpdir('agentic-runtime-') do |project|
        session_id = "verify-#{runtime}-session"
        env = session_env(runtime, session_id)
        FileUtils.mkdir_p(File.join(project, '.agents/workflows'))
        FileUtils.mkdir_p(File.join(project, '.agents/checks'))
        File.write(File.join(project, '.agents/workflows/verified-flow.yaml'), <<~YAML)
          name: verified-flow
          description: 完了条件を満たしてから次へ進む
          steps:
            - name: 01-design
              description: 設計する
              artifacts:
                - design.md
              checks:
                - system-check
              approval: required
            - name: 02-delivery
              description: 成果を届ける
        YAML
        File.write(File.join(project, '.agents/checks/system-check.md'), <<~MARKDOWN)
          # System check

          - [ ] 結果を確認した
        MARKDOWN

        task_id = run_cli(project, 'task create example --workflow verified-flow', env: env).body.fetch('task')
        workspace_path = File.join(project, 'workspace', task_id[0, 4], task_id[0, 6], task_id)
        assert_instruction run_stop(project, runtime, session_id: session_id), runtime, '設計する'

        rejected = run_cli(project, "step complete #{task_id} 01-design", env: env)
        assert_equal 1, rejected.code
        assert_equal 'completion_rejected', rejected.body.fetch('error')
        assert_equal %w[artifact:design.md check:system-check approval],
                     rejected.body.fetch('unmet').map { |unmet| unmet.fetch('condition') }
        assert_equal "01-design\n", File.read(File.join(workspace_path, 'current_step'))
        assert_no_change run_stop(project, runtime, session_id: session_id), runtime

        step = File.join(workspace_path, '01-design')
        File.write(File.join(step, 'design.md'), "# 設計\n")
        File.write(File.join(step, 'checks/system-check.md'), <<~MARKDOWN)
          # System check

          - [x] 結果を確認した
        MARKDOWN

        completed = run_cli(project, "step complete #{task_id} 01-design --approval-evidence 'これで進めてください'", env: env)
        assert_equal 'completed', completed.body.fetch('step_status')
        assert_equal '02-delivery', completed.body.fetch('next_step')
        assert_instruction run_stop(project, runtime, session_id: session_id), runtime, '成果を届ける'
      end
    end
  end
end
