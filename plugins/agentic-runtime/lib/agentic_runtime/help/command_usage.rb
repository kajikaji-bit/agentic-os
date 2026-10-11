# frozen_string_literal: true

module AgenticRuntime
  module Help
    class CommandUsage
      attr_reader :body

      def initialize(name:, reason:, usage:)
        @body = <<~BODY
          #{reason}

          Usage:
            #{usage}

          詳しい使い方は `agentic-runtime #{name} --help` で確かめる。
        BODY
        freeze
      end
    end
  end
end
