# frozen_string_literal: true

require 'did_you_mean'
require_relative 'summary'
require_relative 'root_help'
require_relative 'task_help'
require_relative 'step_help'
require_relative 'session_help'
require_relative 'project_help'
require_relative 'unknown_command'
require_relative 'command_usage'

module AgenticRuntime
  module Help
    class HelpCommands
      COMMANDS = { 'task' => TaskHelp, 'step' => StepHelp, 'session' => SessionHelp,
                   'project' => ProjectHelp }.freeze

      def initialize(actions:, stdout:, stderr:)
        @actions = actions
        @stdout = stdout
        @stderr = stderr
        freeze
      end

      def summary
        @stdout.puts(Summary.new.body)
        nil
      end

      def root
        @stdout.puts(RootHelp.new.body)
        nil
      end

      def command(name, action)
        @stdout.puts(COMMANDS.fetch(name).new(action: action).body)
        nil
      end

      def usage(name, action, reason)
        command = COMMANDS.fetch(name).new(action: action)
        @stderr.puts(CommandUsage.new(name: "#{name} #{action}", reason: reason, usage: command.usage).body)
        nil
      end

      def unknown(name)
        dictionary = @actions.map { |command, action| "#{command} #{action}" } + @actions.map(&:first).uniq
        suggestion = DidYouMean::SpellChecker.new(dictionary: dictionary).correct(name).first
        @stderr.puts(UnknownCommand.new(name: name, suggestion: suggestion).body)
        nil
      end
    end
  end
end
