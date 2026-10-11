# frozen_string_literal: true

module AgenticRuntime
  module Asset
    class Knowledge
      attr_reader :path

      def self.at(path)
        new(path: path)
      end

      private

      def initialize(path:)
        raise ArgumentError, "ナレッジのパスが不正です: #{path}" unless path.is_a?(String) && /\S/.match?(path)
        raise ArgumentError, "ナレッジがプロジェクトの外を指しています: #{path}" if path.start_with?('/') || path.split('/').include?('..')

        @path = path.dup.freeze
        freeze
      end

      private_class_method :new
    end
  end
end
