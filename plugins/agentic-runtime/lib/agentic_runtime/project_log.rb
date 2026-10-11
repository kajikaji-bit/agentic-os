# frozen_string_literal: true

require 'fileutils'
require 'json'
require_relative 'diagnosis'

module AgenticRuntime
  class ProjectLog
    def initialize(root:, runtime:)
      @directory = File.join(Dir.home, '.agentic-runtime/projects', File.expand_path(root).tr('/', '-')).freeze
      @runtime = runtime.dup.freeze
      freeze
    end

    def append(diagnosis)
      session = diagnosis.session
      record = { 'at' => Time.now.getlocal('+09:00').strftime('%Y-%m-%dT%H:%M:%S%:z'),
                 'level' => diagnosis.level, 'reason' => diagnosis.reason }
      record['session'] = session.id if session
      name = session ? "#{@runtime}-#{session.id}.jsonl" : "#{@runtime}.jsonl"
      FileUtils.mkdir_p(@directory)
      File.open(File.join(@directory, name), 'a') { |file| file.puts(JSON.generate(record)) }
      nil
    rescue StandardError
      nil
    end
  end
end
