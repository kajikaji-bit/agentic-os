# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'shellwords'
require 'tmpdir'

module Helper
  PLUGIN_ROOT = File.expand_path('..', __dir__)

  Result = Data.define(:code, :body)

  def run_cli(project, command, env: {})
    invoke(project, 'bin/agentic-runtime', *Shellwords.split(command), env: env)
  end

  def run_stop(project, runtime, session_id:)
    input = if runtime == 'cursor'
              { 'hook_event_name' => 'stop', 'conversation_id' => session_id }
            else
              { 'hook_event_name' => 'Stop', 'session_id' => session_id }
            end
    invoke(project, 'hooks/agentic-runtime.rb', runtime, input: JSON.generate(input))
  end

  def session_env(runtime, session_id)
    variable = {
      'claude' => 'CLAUDE_CODE_SESSION_ID',
      'codex' => 'CODEX_THREAD_ID',
      'cursor' => 'CURSOR_SESSION_ID'
    }.fetch(runtime)
    { variable => session_id }
  end

  def assert_instruction(response, runtime, description)
    if runtime == 'cursor'
      assert_includes response.body.fetch('followup_message'), description
    else
      assert_equal 'block', response.body.fetch('decision')
      assert_includes response.body.fetch('reason'), description
    end
  end

  def assert_no_change(response, runtime)
    expected = runtime == 'codex' ? { 'continue' => true } : {}
    assert_equal expected, response.body
  end

  private

  def invoke(project, entry, *arguments, input: '', env: {})
    environment = ENV.keys.grep(/\A(?:CLAUDE|CODEX|CURSOR)_.*(?:SESSION|THREAD|CONVERSATION)_ID\z/)
                     .each_with_object({}) { |key, clean| clean[key] = nil }
    output, error, status = Open3.capture3(
      environment.merge(env), RbConfig.ruby, File.join(PLUGIN_ROOT, entry), *arguments,
      stdin_data: input, chdir: project
    )
    Result.new(status.exitstatus, JSON.parse(status.success? ? output : error))
  end
end
