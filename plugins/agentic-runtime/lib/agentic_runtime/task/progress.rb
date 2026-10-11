# frozen_string_literal: true

module AgenticRuntime
  module Task
    class Progress
      attr_reader :task_status, :current_step_name, :next_step_name

      def in_progress?
        !@current_step_name.nil?
      end

      def completed?
        @current_step_name.nil? && @next_step_name.nil?
      end

      def initialize(task_status:, current_step_name:, next_step_name:)
        @task_status = task_status.dup.freeze
        @current_step_name = current_step_name&.dup&.freeze
        @next_step_name = next_step_name&.dup&.freeze
        freeze
      end
    end
  end
end
