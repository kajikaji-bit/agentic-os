# frozen_string_literal: true

module AgenticRuntime
  module Asset
    class StepAssets
      attr_reader :checklists

      def initialize(checklists:)
        @checklists = checklists.dup.freeze
        freeze
      end
    end
  end
end
