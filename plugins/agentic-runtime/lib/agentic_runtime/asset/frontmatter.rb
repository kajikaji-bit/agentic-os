# frozen_string_literal: true

require 'yaml'

module AgenticRuntime
  module Asset
    class Frontmatter
      def self.of(yaml, path:)
        properties = YAML.safe_load(yaml)
        raise ArgumentError, "frontmatter が不正です: #{path}" unless properties.is_a?(Hash)

        new(properties: properties.compact.freeze)
      rescue Psych::Exception => e
        raise ArgumentError, "frontmatter が不正です: #{path} (#{e.message})"
      end

      def fetch(key, default)
        @properties.fetch(key, default)
      end

      private

      def initialize(properties:)
        @properties = properties
        freeze
      end

      private_class_method :new
    end
  end
end
