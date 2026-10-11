# frozen_string_literal: true

require_relative 'markdown'

module AgenticRuntime
  module Asset
    class Skill
      attr_reader :name, :path

      def self.from_markdown(markdown, path:)
        new(path: path, markdown: markdown)
      end

      private

      def initialize(path:, markdown:)
        @path = path.dup.freeze
        @name = skill_name(Markdown.parse(markdown, path: path).frontmatter.fetch('name', nil))
        freeze
      end

      def skill_name(name)
        raise ArgumentError, "スキルの名前が不正です: #{@path}" unless name.is_a?(String) && /\S/.match?(name)

        name.dup.freeze
      end

      private_class_method :new
    end
  end
end
