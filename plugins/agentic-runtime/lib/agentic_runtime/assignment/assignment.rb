# frozen_string_literal: true

require_relative '../event'

module AgenticRuntime
  module Assignment
    class Assignment
      attr_reader :task_id, :session

      def self.assign(task:, session:)
        raise ArgumentError, 'クローズしたタスクには割り当てられません' unless task.progress.task_status == 'created'

        attached = Event.new(name: 'session.attached', attributes: { 'runtime' => session.runtime, 'id' => session.id })
        new(task_id: task.id, session: session, events: [attached])
      end

      def self.restore(task_id:, session:)
        new(task_id: task_id, session: session, events: [])
      end

      def release_events
        @events.dup.freeze
      end

      def clear_events
        @events.clear
        nil
      end

      private

      def initialize(task_id:, session:, events:)
        @task_id = task_id
        @session = session
        @events = events.dup
      end

      private_class_method :new
    end
  end
end
