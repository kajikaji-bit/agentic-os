# frozen_string_literal: true

require_relative 'workflow'

module AgenticRuntime
  module Asset
    class Catalog
      def initialize(root:)
        @directory = File.join(root, '.agents/workflows').freeze
        freeze
      end

      def find(name)
        matches = Dir.glob(File.join(@directory, '*.{yaml,yml}')).sort.map do |path|
          workflow = Workflow.parse(File.read(path))
          workflow if workflow.name == name
        end.compact
        raise ArgumentError, "ワークフローを一つに選べません: #{name}" unless matches.size == 1

        matches.first
      end
    end
  end
end
