# frozen_string_literal: true

module AgenticRuntime
  module Help
    class ProjectHelp
      attr_reader :body, :usage

      def initialize(action: nil)
        case action
        when 'doctor'
          @usage = 'agentic-runtime project doctor [<task-id>]'
          @body = <<~BODY
            プロジェクトを検査して不整合を報告する

            Usage:
              #{@usage}

            Options:
              -h, --help  ヘルプを表示する

            タスクを指定するとそのタスクのワークスペースだけを、指定しなければすべてのタスクを検査する。
          BODY
        else
          @usage = 'agentic-runtime project <action> [arguments]'
          @body = <<~BODY
            Usage:
              #{@usage}

            Commands:
              project doctor  プロジェクトを検査して不整合を報告する

            Options:
              -h, --help  ヘルプを表示する

            アクションごとの使い方は `agentic-runtime project <action> --help` で確かめる。
          BODY
        end
        freeze
      end
    end
  end
end
