# frozen_string_literal: true

module AgenticRuntime
  module Asset
    class Checklist
      attr_reader :name, :path, :body

      def self.from_markdown(markdown, path:)
        new(path: path, body: markdown)
      end

      def checked?
        @checks.all? { |check| check[:checked] }
      end

      private

      def initialize(path:, body:)
        @name = File.basename(path, '.md').freeze
        @path = path.dup.freeze
        @body = body.dup.freeze
        @checks = body.scan(/^\s*- \[([ xX])\] *(.*)$/).map do |mark, content|
          { checked: mark.casecmp?('x'), content: content.strip.freeze }.freeze
        end.freeze
        freeze
      end

      private_class_method :new
    end
  end
end
