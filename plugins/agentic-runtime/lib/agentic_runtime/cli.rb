# frozen_string_literal: true

require_relative 'invalid_usage'
require_relative 'help/help_commands'
require_relative 'task/task_commands'
require_relative 'step/step_commands'
require_relative 'assignment/session_commands'
require_relative 'project/project_commands'

module AgenticRuntime
  module CLI
    HELP_FLAGS = %w[-h --help].freeze

    ACTIONS = {
      %w[task create] => [Task::TaskCommands, :create],
      %w[task close] => [Task::TaskCommands, :close],
      %w[step complete] => [Step::StepCommands, :complete],
      %w[step cancel] => [Step::StepCommands, :cancel],
      %w[session attach] => [Assignment::SessionCommands, :attach],
      %w[project doctor] => [Project::ProjectCommands, :doctor]
    }.freeze

    def self.run(arguments, stdout:, stderr:)
      words = arguments - HELP_FLAGS
      words = words.drop(1) if words.first == 'help'
      command, action, *values = words
      help = Help::HelpCommands.new(actions: ACTIONS.keys, stdout: stdout, stderr: stderr)
      actions = ACTIONS.keys.select { |key| key.first == command }

      if arguments.empty?
        help.summary
        return 0
      end

      if command.nil?
        help.root
        return 0
      end

      unless actions.include?([command, action]) || (action.nil? && actions.any?)
        help.unknown([command, action].compact.join(' '))
        return 1
      end

      if arguments.first == 'help' || arguments.intersect?(HELP_FLAGS) || action.nil?
        help.command(command, action)
        return 0
      end

      controller, method = ACTIONS.fetch([command, action])
      controller.new(root: Dir.pwd, stdout: stdout).public_send(method, values)
    rescue Step::Step::CompletionRejected => e
      stderr.puts(JSON.generate(error: 'completion_rejected', task: e.task_id.to_s, step: e.step_name, unmet: e.unmet))
      1
    rescue InvalidUsage => e
      help.usage(command, action, e.message)
      1
    rescue ArgumentError, KeyError, SystemCallError => e
      stderr.puts("ERROR: #{e.message}")
      1
    end
  end
end
