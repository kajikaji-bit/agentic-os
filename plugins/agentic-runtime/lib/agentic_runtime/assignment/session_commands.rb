# frozen_string_literal: true

require 'json'
require_relative '../invalid_usage'
require_relative '../task/workspace'
require_relative '../task/task_id'
require_relative 'session'
require_relative 'attach_session'
require_relative 'assignees'

module AgenticRuntime
  module Assignment
    class SessionCommands
      def initialize(root:, stdout:)
        @attach_session = AttachSession.new(workspace: Task::Workspace.new(root: root),
                                            assignees: Assignees.new(root: root))
        @stdout = stdout
        freeze
      end

      def attach(arguments)
        id, *rest = arguments
        raise InvalidUsage, '足りない引数です: タスク ID' unless id
        raise InvalidUsage, "余分な引数です: #{rest.join(' ')}" if rest.any?

        assignment = @attach_session.attach(task_id: Task::TaskId.parse(id),
                                            session: Session.from_environment_variables)
        session = assignment.session
        @stdout.puts(JSON.generate(task: assignment.task_id.to_s, runtime: session.runtime, id: session.id))
        0
      end
    end
  end
end
