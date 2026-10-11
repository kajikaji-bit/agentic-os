# frozen_string_literal: true

module AgenticRuntime
  module Help
    class StepHelp
      attr_reader :body, :usage

      def initialize(action: nil)
        case action
        when 'complete'
          @usage = 'agentic-runtime step complete <task-id> <step> [--approval-evidence <text>]'
          @body = <<~BODY
            進行中のステップの完了条件を判定して完了する

            Usage:
              #{@usage}

            Options:
              --approval-evidence <text>  承認者本人の発言
              -h, --help                  ヘルプを表示する
          BODY
        when 'cancel'
          @usage = 'agentic-runtime step cancel <task-id> <step>'
          @body = <<~BODY
            進行中のステップをキャンセルする

            Usage:
              #{@usage}

            Options:
              -h, --help  ヘルプを表示する
          BODY
        else
          @usage = 'agentic-runtime step <action> [arguments]'
          @body = <<~BODY
            Usage:
              #{@usage}

            Commands:
              step complete  進行中のステップの完了条件を判定して完了する
              step cancel    進行中のステップをキャンセルする

            Options:
              -h, --help  ヘルプを表示する

            アクションごとの使い方は `agentic-runtime step <action> --help` で確かめる。
          BODY
        end
        freeze
      end
    end
  end
end
