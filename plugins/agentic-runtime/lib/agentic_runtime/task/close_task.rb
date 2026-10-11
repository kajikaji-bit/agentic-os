# frozen_string_literal: true

module AgenticRuntime
  module Task
    class CloseTask
      def initialize(workspace:)
        @workspace = workspace
        freeze
      end

      def close(task_id:)
        task = @workspace.find(task_id)
        task.close
        @workspace.save(task)
        @workspace.find(task_id)
      end
    end
  end
end
