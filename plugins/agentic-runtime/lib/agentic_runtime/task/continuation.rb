# frozen_string_literal: true

module AgenticRuntime
  module Task
    class Continuation
      def initialize
        freeze
      end

      def decide(progress:)
        return :continue if progress.in_progress?
        return :done if progress.completed?

        :next
      end
    end
  end
end
