# frozen_string_literal: true

module AgenticRuntime
  module Help
    class Summary
      attr_reader :body

      def initialize
        @body = <<~BODY
          ワークフローに従ってタスクをステップごとに進める

          Examples:
            agentic-runtime task create search-filter --workflow software-delivery
            agentic-runtime step complete 20261006-search-filter 01-design

          詳しい使い方は `agentic-runtime --help` で確かめる。
        BODY
        freeze
      end
    end
  end
end
