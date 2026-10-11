# frozen_string_literal: true

module AgenticRuntime
  module Help
    class RootHelp
      attr_reader :body

      def initialize
        @body = <<~BODY
          ワークフローに従ってタスクをステップごとに進める

          Usage:
            agentic-runtime <command> <action> [arguments]

          Examples:
            agentic-runtime task create search-filter --workflow software-delivery
            agentic-runtime step complete 20261006-search-filter 01-design

          Commands:
            task create     タスクを作ってワークスペースを用意する
            task close      タスクをクローズする
            step complete   進行中のステップの完了条件を判定して完了する
            step cancel     進行中のステップをキャンセルする
            session attach  セッションをタスクに紐付ける
            project doctor  プロジェクトを検査して不整合を報告する

          Options:
            -h, --help  ヘルプを表示する

          コマンドごとの使い方は `agentic-runtime <command> --help` で確かめる。
        BODY
        freeze
      end
    end
  end
end
