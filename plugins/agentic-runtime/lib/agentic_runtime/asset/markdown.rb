# frozen_string_literal: true

require_relative 'frontmatter'

module AgenticRuntime
  module Asset
    class Markdown
      attr_reader :frontmatter, :body

      def self.parse(text, path:)
        matched = /\A---[ \t]*\r?\n(.*?)^---[ \t]*\r?\n?/m.match(text)
        raise ArgumentError, "frontmatter がありません: #{path}" unless matched

        new(frontmatter: Frontmatter.of(matched[1], path: path), body: matched.post_match)
      end

      private

      def initialize(frontmatter:, body:)
        @frontmatter = frontmatter
        @body = body.freeze
        freeze
      end

      private_class_method :new
    end
  end
end
