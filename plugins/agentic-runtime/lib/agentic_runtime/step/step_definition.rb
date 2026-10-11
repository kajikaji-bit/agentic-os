# frozen_string_literal: true

require 'pathname'

module AgenticRuntime
  module Step
    class StepDefinition
      attr_reader :name, :description, :read, :using, :artifacts, :checks, :rules, :agent

      def initialize(name:, description:, read: [], using: [], artifacts: [], checks: [], rules: [], approval: nil,
                     agent: nil)
        raise ArgumentError, 'ステップ名が必要です' unless name.is_a?(String) && /\S/.match?(name)
        raise ArgumentError, '仕事内容が必要です' unless description.is_a?(String) && /\S/.match?(description)

        @name = name.dup.freeze
        @description = description.dup.freeze
        @read = read.uniq(&:path).freeze
        raise ArgumentError, 'スキル名には配列が必要です' unless using.is_a?(Array)

        @using = using.uniq.map do |skill_name|
          raise ArgumentError, "スキル名が不正です: #{skill_name}" unless skill_name.is_a?(String) && /\S/.match?(skill_name)

          skill_name.dup.freeze
        end.freeze
        raise ArgumentError, '成果物の宣言には配列が必要です' unless artifacts.is_a?(Array)

        @artifacts = artifacts.uniq.map do |file|
          raise ArgumentError, '成果物の宣言が不正です' unless file.is_a?(String) && /\S/.match?(file)

          path = Pathname.new(file)
          if path.absolute? || path.cleanpath.to_s == '.' || path.cleanpath.each_filename.first == '..'
            raise ArgumentError, "成果物の宣言がステップの外を指しています: #{file}"
          end

          file.dup.freeze
        end.freeze
        raise ArgumentError, 'チェックリスト名には配列が必要です' unless checks.is_a?(Array)

        @checks = checks.uniq.map do |check_name|
          raise ArgumentError, "チェックリスト名が不正です: #{check_name}" unless check_name.is_a?(String) && /\S/.match?(check_name)

          check_name.dup.freeze
        end.freeze
        raise ArgumentError, 'ルール名には配列が必要です' unless rules.is_a?(Array)

        @rules = rules.uniq.map do |rule_name|
          raise ArgumentError, "ルール名が不正です: #{rule_name}" unless rule_name.is_a?(String) && /\S/.match?(rule_name)

          rule_name.dup.freeze
        end.freeze
        raise ArgumentError, "承認の要否が不正です: #{approval}" unless [nil, 'required'].include?(approval)

        @approval_required = approval == 'required'
        raise ArgumentError, "ロール名が不正です: #{agent}" unless agent.nil? || (agent.is_a?(String) && /\S/.match?(agent))

        @agent = agent&.dup&.freeze
        freeze
      end

      def approval_required?
        @approval_required
      end
    end
  end
end
