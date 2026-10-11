# frozen_string_literal: true

require_relative 'step_directory'
require_relative '../event'
require_relative '../workspace_log'

module AgenticRuntime
  module Step
    class SendDirective
      def initialize(root:, task:)
        @root = File.expand_path(root).freeze
        @task = task
        @log = WorkspaceLog.new(root: @root, task_id: task.id)
        freeze
      end

      def send(session:)
        step_name = @task.progress.current_step_name
        sent = { 'step' => step_name, 'runtime' => session.runtime, 'id' => session.id }
        return nil if @log.events.any? { |event| event.name == 'directive.sent' && event.attributes == sent }

        @log.append(Event.new(name: 'directive.sent', attributes: sent))
        StepDirectory.new(root: @root, task_id: @task.id, step_name: step_name).directive.body
      end
    end
  end
end
