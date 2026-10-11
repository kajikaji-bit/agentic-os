# frozen_string_literal: true

require_relative '../invalid_usage'
require_relative 'doctor'
require_relative '../task/task_id'

module AgenticRuntime
  module Project
    class ProjectCommands
      def initialize(root:, stdout:)
        @doctor = Doctor.new(root: root)
        @stdout = stdout
        freeze
      end

      def doctor(arguments)
        id, *rest = arguments
        raise InvalidUsage, "余分な引数です: #{rest.join(' ')}" if rest.any?

        result = @doctor.check(task_id: id && Task::TaskId.parse(id))
        if result.ok?
          @stdout.puts('不整合はありません')
          return 0
        end

        @stdout.puts(result.inconsistencies)
        1
      end
    end
  end
end
