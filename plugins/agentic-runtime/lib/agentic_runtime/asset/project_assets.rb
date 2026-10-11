# frozen_string_literal: true

require_relative 'checklist'
require_relative 'knowledge'
require_relative 'role'
require_relative 'rule'
require_relative 'skill'
require_relative 'step_assets'

module AgenticRuntime
  module Asset
    class ProjectAssets
      def initialize(root:)
        @root = File.expand_path(root).freeze
        freeze
      end

      def for_step(definition:)
        (definition.read.grep(Knowledge) + rules(definition: definition).flat_map(&:read)).map(&:path).each do |path|
          location = File.join(@root, path)
          unless File.file?(location) && File.realpath(location).start_with?("#{File.realpath(@root)}/")
            raise ArgumentError, "ナレッジが見つかりません: #{path}"
          end
        end
        skills(definition: definition)
        role(definition: definition)
        checklists = checks(definition: definition).map do |name|
          paths = Dir.glob(File.join(@root, '.agents/checks/**', "#{name}.md")).sort.select { |path| File.file?(path) }
          raise ArgumentError, "チェックリストが見つかりません: #{name}" if paths.empty?
          raise ArgumentError, "チェックリストが重複しています: #{name}" if paths.size > 1
          unless File.realpath(paths.first).start_with?("#{File.realpath(@root)}/")
            raise ArgumentError, "チェックリストがプロジェクトの外を指しています: #{name}"
          end

          Checklist.from_markdown(File.read(paths.first), path: paths.first.delete_prefix("#{@root}/"))
        end
        StepAssets.new(checklists: checklists)
      end

      def checks(definition:)
        (definition.checks + rules(definition: definition).flat_map(&:checks)).uniq
      end

      def rules(definition:)
        definition.rules.uniq.map do |name|
          paths = [File.join(@root, '.agents/rules', "#{name}.md")]
          paths += Dir.glob(File.join(@root, 'wiki/**/*.rule.md')).select do |path|
            File.basename(path, '.rule.md') == name
          end
          paths.select! { |path| File.file?(path) }
          raise ArgumentError, "ルールが見つかりません: #{name}" if paths.empty?
          raise ArgumentError, "ルールが重複しています: #{name}" if paths.size > 1

          path = paths.first
          unless File.realpath(path).start_with?("#{File.realpath(@root)}/")
            raise ArgumentError, "ルールがプロジェクトの外を指しています: #{name}"
          end

          Rule.from_markdown(File.read(path), path: path.delete_prefix("#{@root}/"))
        end
      end

      def skills(definition:)
        paths = Dir.glob(File.join(@root, '.agents/skills/**/SKILL.md')).sort.select { |path| File.file?(path) }
        skills = paths.map do |path|
          unless File.realpath(path).start_with?("#{File.realpath(@root)}/")
            raise ArgumentError, "スキルがプロジェクトの外を指しています: #{path}"
          end

          Skill.from_markdown(File.read(path), path: path.delete_prefix("#{@root}/"))
        end
        (definition.using + rules(definition: definition).flat_map(&:using)).uniq.map do |name|
          matched = skills.select { |skill| skill.name == name }
          raise ArgumentError, "スキルが見つかりません: #{name}" if matched.empty?
          raise ArgumentError, "スキルが重複しています: #{name}" if matched.size > 1

          matched.first
        end
      end

      def role(definition:)
        return nil if definition.agent.nil?

        paths = Dir.glob(File.join(@root, '.agents/agents/**/*.md')).sort.select { |path| File.file?(path) }
        roles = paths.map do |path|
          unless File.realpath(path).start_with?("#{File.realpath(@root)}/")
            raise ArgumentError, "ロールがプロジェクトの外を指しています: #{path}"
          end

          Role.from_markdown(File.read(path), path: path.delete_prefix("#{@root}/"))
        end
        matched = roles.select { |role| role.name == definition.agent }
        raise ArgumentError, "ロールが見つかりません: #{definition.agent}" if matched.empty?
        raise ArgumentError, "ロールが重複しています: #{definition.agent}" if matched.size > 1

        matched.first
      end
    end
  end
end
