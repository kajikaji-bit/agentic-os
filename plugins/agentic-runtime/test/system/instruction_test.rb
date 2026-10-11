# frozen_string_literal: true

require_relative '../helper'

class TestInstruction < Minitest::Test
  include Helper

  %w[claude codex cursor].each do |runtime|
    define_method("test_instruction_with_assets_at_#{runtime}") do
      Dir.mktmpdir('agentic-runtime-') do |project|
        session_id = "assets-#{runtime}-session"
        env = session_env(runtime, session_id)
        %w[.agents/workflows .agents/checks .agents/rules .agents/agents .agents/skills/review docs].each do |directory|
          FileUtils.mkdir_p(File.join(project, directory))
        end
        File.write(File.join(project, '.agents/workflows/materials-flow.yaml'), <<~YAML)
          name: materials-flow
          description: 資料を受け取って成果を届ける
          steps:
            - name: 01-design
              description: 設計する
              artifacts:
                - design.md
            - name: 02-delivery
              description: 成果を届ける
              agent: reviewer
              using:
                - review
              rules:
                - reviewing
              read:
                - 01-design/design.md
              checks:
                - system-check
        YAML
        File.write(File.join(project, '.agents/agents/reviewer.md'), <<~MARKDOWN)
          ---
          name: reviewer
          description: 成果をレビューする
          ---

          観点を三つ挙げてから読む。
        MARKDOWN
        File.write(File.join(project, '.agents/rules/reviewing.md'), <<~MARKDOWN)
          ---
          name: reviewing
          read:
            - docs/decisions.md
          ---

          - 結論を先に書く。
        MARKDOWN
        File.write(File.join(project, '.agents/skills/review/SKILL.md'), <<~MARKDOWN)
          ---
          name: review
          description: レビューの進め方
          ---

          # Review
        MARKDOWN
        File.write(File.join(project, '.agents/checks/system-check.md'), <<~MARKDOWN)
          # System check

          - [ ] 結果を確認した
        MARKDOWN
        File.write(File.join(project, 'docs/decisions.md'), "# 決めたこと\n")

        task_id = run_cli(project, 'task create example --workflow materials-flow', env: env).body.fetch('task')
        workspace_path = File.join(project, 'workspace', task_id[0, 4], task_id[0, 6], task_id)
        assert_instruction run_stop(project, runtime, session_id: session_id), runtime, '設計する'

        FileUtils.mkdir_p(File.join(workspace_path, '01-design'))
        File.write(File.join(workspace_path, '01-design/design.md'), "# 設計\n")
        run_cli(project, "step complete #{task_id} 01-design", env: env)

        materials = run_stop(project, runtime, session_id: session_id)
        assert_instruction materials, runtime, '成果を届ける'
        assert_instruction materials, runtime, '成果をレビューする'
        assert_instruction materials, runtime, '観点を三つ挙げてから読む。'
        assert_instruction materials, runtime, '- 結論を先に書く。'
        assert_instruction materials, runtime, '.agents/skills/review/SKILL.md'
        assert_instruction materials, runtime, 'docs/decisions.md'
        assert_instruction materials, runtime, '01-design/design.md'
        assert_instruction materials, runtime, '02-delivery/checks/system-check.md'
      end
    end
  end
end
