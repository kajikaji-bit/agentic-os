# frozen_string_literal: true

require_relative 'markdown'
require_relative 'knowledge'

module AgenticRuntime
  module Asset
    class Rule
      attr_reader :name, :body, :using, :read, :checks

      def self.from_markdown(markdown, path:)
        new(path: path, markdown: markdown)
      end

      private

      def initialize(path:, markdown:)
        @name = File.basename(path).delete_suffix('.md').delete_suffix('.rule').freeze
        document = Markdown.parse(markdown, path: path)
        frontmatter = document.frontmatter
        using = frontmatter.fetch('using', [])
        raise ArgumentError, "ルールのスキル名には配列が必要です: #{@name}" unless using.is_a?(Array)

        @using = using.uniq.map do |name|
          raise ArgumentError, "スキル名が不正です: #{name}" unless name.is_a?(String) && /\S/.match?(name)

          name.dup.freeze
        end.freeze
        read = frontmatter.fetch('read', [])
        raise ArgumentError, "ルールの読むものには配列が必要です: #{@name}" unless read.is_a?(Array)

        @read = read.uniq.map { |path| Knowledge.at(path) }.freeze
        checks = frontmatter.fetch('checks', [])
        raise ArgumentError, "ルールのチェックリスト名には配列が必要です: #{@name}" unless checks.is_a?(Array)

        @checks = checks.uniq.map do |name|
          raise ArgumentError, "チェックリスト名が不正です: #{name}" unless name.is_a?(String) && /\S/.match?(name)

          name.dup.freeze
        end.freeze
        @body = document.body.strip.freeze
        freeze
      end

      private_class_method :new
    end
  end
end
