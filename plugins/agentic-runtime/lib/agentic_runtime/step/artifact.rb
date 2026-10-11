# frozen_string_literal: true

module AgenticRuntime
  module Step
    class Artifact
      def self.of(step_name:, file:)
        new(step_name: step_name, file: file)
      end

      def path
        File.join(@step_name, @file)
      end

      private

      def initialize(step_name:, file:)
        @step_name = step_name.dup.freeze
        @file = file.dup.freeze
        freeze
      end

      private_class_method :new
    end
  end
end
