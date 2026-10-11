# frozen_string_literal: true

module AgenticRuntime
  module Step
    class CompletionVerdict
      attr_reader :unmet

      def initialize(unmet:)
        @unmet = unmet.map { |item| item.transform_values { |value| value.dup.freeze }.freeze }.freeze
        freeze
      end

      def accepted?
        @unmet.empty?
      end
    end
  end
end
