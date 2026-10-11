# frozen_string_literal: true

require 'json'

module AgenticRuntime
  module Assignment
    class Session
      VARIABLES = {
        'CLAUDE_CODE_SESSION_ID' => 'claude', 'CLAUDE_SESSION_ID' => 'claude',
        'CLAUDE_THREAD_ID' => 'claude', 'CLAUDE_CONVERSATION_ID' => 'claude',
        'CODEX_SESSION_ID' => 'codex', 'CODEX_THREAD_ID' => 'codex', 'CODEX_CONVERSATION_ID' => 'codex',
        'CURSOR_SESSION_ID' => 'cursor', 'CURSOR_THREAD_ID' => 'cursor', 'CURSOR_CONVERSATION_ID' => 'cursor'
      }.freeze

      attr_reader :runtime, :id

      def self.from(runtime:, id:)
        new(runtime: runtime, id: id)
      end

      def self.from_hook_input(runtime:, input:)
        event = JSON.parse(input)
        event_name, id_key = runtime == 'cursor' ? %w[stop conversation_id] : %w[Stop session_id]
        return nil unless event.is_a?(Hash) && event['hook_event_name'] == event_name && event[id_key]

        from(runtime: runtime, id: event.fetch(id_key))
      end

      def self.from_environment_variables
        variable = VARIABLES.keys.find { |key| /\S/.match?(ENV.fetch(key, '')) }
        raise ArgumentError, 'Session IDが必要です' unless variable

        from(runtime: VARIABLES.fetch(variable), id: ENV.fetch(variable))
      end

      def ==(other)
        other.is_a?(Session) && [runtime, id] == [other.runtime, other.id]
      end

      private

      def initialize(runtime:, id:)
        raise ArgumentError, 'ランタイムが不正です' unless %w[claude codex cursor].include?(runtime)
        raise ArgumentError, 'Session IDが必要です' unless id.is_a?(String) && /\A\S+\z/.match?(id)

        @runtime = runtime.dup.freeze
        @id = id.dup.freeze
        freeze
      end

      private_class_method :new
    end
  end
end
