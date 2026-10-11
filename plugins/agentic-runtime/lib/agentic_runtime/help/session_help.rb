# frozen_string_literal: true

module AgenticRuntime
  module Help
    class SessionHelp
      attr_reader :body, :usage

      def initialize(action: nil)
        case action
        when 'attach'
          @usage = 'agentic-runtime session attach <task-id>'
          @body = <<~BODY
            セッションをタスクに紐付ける

            Usage:
              #{@usage}

            Options:
              -h, --help  ヘルプを表示する
          BODY
        else
          @usage = 'agentic-runtime session <action> [arguments]'
          @body = <<~BODY
            Usage:
              #{@usage}

            Commands:
              session attach  セッションをタスクに紐付ける

            Options:
              -h, --help  ヘルプを表示する

            アクションごとの使い方は `agentic-runtime session <action> --help` で確かめる。
          BODY
        end
        freeze
      end
    end
  end
end
