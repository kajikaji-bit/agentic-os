# frozen_string_literal: true

require_relative 'markdown'

module AgenticRuntime
  module Asset
    class Role
      attr_reader :name, :description, :body, :path

      def self.from_markdown(markdown, path:)
        new(path: path, markdown: markdown)
      end

      private

      def initialize(path:, markdown:)
        @path = path.dup.freeze
        document = Markdown.parse(markdown, path: path)
        frontmatter = document.frontmatter
        @name = text(frontmatter.fetch('name', nil), 'name')
        @description = text(frontmatter.fetch('description', nil), 'description')
        @body = document.body.strip.freeze
        freeze
      end

      def text(value, label)
        raise ArgumentError, "ロールの #{label} が不正です: #{@path}" unless value.is_a?(String) && /\S/.match?(value)

        value.dup.freeze
      end

      private_class_method :new
    end
  end
end
