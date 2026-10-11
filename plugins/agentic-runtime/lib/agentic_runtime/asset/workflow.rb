# frozen_string_literal: true

require 'yaml'
require_relative 'knowledge'
require_relative '../step/artifact'
require_relative '../step/step_definition'

module AgenticRuntime
  module Asset
    class Workflow
      attr_reader :name, :steps, :source

      def self.parse(source)
        data = YAML.safe_load(source)
        raise ArgumentError, 'ワークフローには名前とステップが必要です' unless data.is_a?(Hash)

        attributes = data.compact
        entries = attributes.fetch('steps')
        rules = attributes.fetch('rules', [])
        raise ArgumentError, 'ステップが必要です' unless entries.is_a?(Array) && entries.any?
        raise ArgumentError, 'ステップには名前と仕事内容が必要です' unless entries.all?(Hash)

        names = entries.map { |entry| entry['name'] }
        raise ArgumentError, 'ステップ名が重複しています' unless names.uniq == names

        steps = entries.each_with_object([]) do |entry, previous|
          step = entry.compact
          read = step.fetch('read', [])
          step_rules = step.fetch('rules', [])
          raise ArgumentError, '読むものには配列が必要です' unless read.is_a?(Array) && read.all?(String)
          raise ArgumentError, 'ルール名には配列が必要です' unless step_rules.is_a?(Array) && rules.is_a?(Array)

          reading_list = read.map do |path|
            step_name, file = path.split('/', 2)
            next Knowledge.at(path) unless names.include?(step_name)

            if previous.none? { |declared| declared.name == step_name && declared.artifacts.include?(file) }
              raise ArgumentError, "前のステップが宣言していない成果物です: #{path}"
            end

            Step::Artifact.of(step_name: step_name, file: file)
          end
          previous << Step::StepDefinition.new(
            name: step.fetch('name'),
            description: step.fetch('description'),
            read: reading_list,
            using: step.fetch('using', []),
            artifacts: step.fetch('artifacts', []),
            checks: step.fetch('checks', []),
            rules: step_rules + rules,
            approval: step['approval'],
            agent: step['agent']
          )
        end
        new(name: attributes.fetch('name'), steps: steps, source: source)
      rescue Psych::Exception, KeyError, TypeError => e
        raise ArgumentError, "ワークフローが不正です: #{e.message}"
      end

      private

      def initialize(name:, steps:, source:)
        raise ArgumentError, 'ワークフロー名が必要です' unless name.is_a?(String) && /\S/.match?(name)

        @name = name.dup.freeze
        @steps = steps.freeze
        @source = source.dup.freeze
        freeze
      end

      private_class_method :new
    end
  end
end
