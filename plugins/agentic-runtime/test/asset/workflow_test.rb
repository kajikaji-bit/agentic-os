# frozen_string_literal: true

require 'minitest/autorun'

require_relative '../../lib/agentic_runtime/asset/workflow'

class TestWorkflow < Minitest::Test
  def test_do_not_read_an_artifact_that_no_previous_step_declares
    source = <<~YAML
      name: release-review
      description: 公開前に変更内容を確認する
      steps:
        - name: 01-inspect
          description: 公開する変更点を確認する
          read:
            - 02-summarize/summary.md
        - name: 02-summarize
          description: 確認した結果をまとめる
          artifacts:
            - summary.md
    YAML

    assert_raises(ArgumentError) { AgenticRuntime::Asset::Workflow.parse(source) }
  end
end
