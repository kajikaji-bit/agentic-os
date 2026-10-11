# frozen_string_literal: true

require_relative 'assignment'
require_relative '../workspace_log'
require_relative '../workspace_path'
require_relative '../task/workspace'
require_relative 'session'

module AgenticRuntime
  module Assignment
    class Assignees
      def initialize(root:)
        @root = File.expand_path(root).freeze
        @workspace = Task::Workspace.new(root: @root)
        freeze
      end

      def find_by(session:)
        path = @workspace.paths.find do |candidate|
          file = File.join(candidate.value, 'session')
          next false unless File.exist?(file)

          runtime, id = File.read(file).split
          next unless Session.from(runtime: runtime, id: id) == session

          log = WorkspaceLog.new(root: @root, task_id: candidate.task_id)
          log.events.none? { |event| event.name == 'task.closed' }
        end
        return nil unless path

        Assignment.restore(task_id: path.task_id, session: session)
      end

      def save(assignment)
        session = assignment.session
        path = WorkspacePath.for(root: @root, task_id: assignment.task_id)
        File.write(File.join(path.value, 'session'), "#{session.runtime} #{session.id}\n")
        WorkspaceLog.new(root: @root, task_id: assignment.task_id).append(assignment.release_events)
        assignment.clear_events
      end
    end
  end
end
