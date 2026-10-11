# frozen_string_literal: true

module AgenticRuntime
  module Help
    class UnknownCommand
      attr_reader :body

      def initialize(name:, suggestion: nil)
        message = ["知らないコマンドです: #{name}"]
        message << "もしかして: agentic-runtime #{suggestion}" if suggestion
        @body = <<~BODY
          #{message.join("\n")}

          Usage:
            agentic-runtime <command> <action> [arguments]

          使えるコマンドは `agentic-runtime --help` で確かめる。
        BODY
        @body.freeze
        freeze
      end
    end
  end
end
