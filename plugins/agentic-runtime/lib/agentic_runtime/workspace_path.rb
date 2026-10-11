# frozen_string_literal: true

require_relative 'task/task_id'

module AgenticRuntime
  class WorkspacePath
    attr_reader :task_id, :value

    def self.for(root:, task_id:)
      new(root: root, task_id: task_id)
    end

    private

    def initialize(root:, task_id:)
      raise ArgumentError, 'タスク ID が必要です' unless task_id.is_a?(Task::TaskId)

      id = task_id.to_s
      @task_id = task_id
      @value = File.join(File.expand_path(root), 'workspace', id[0, 4], id[0, 6], id).freeze
      freeze
    end

    private_class_method :new
  end
end
