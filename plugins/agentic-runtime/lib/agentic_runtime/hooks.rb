# frozen_string_literal: true

require 'json'
require_relative 'task/workspace'
require_relative 'assignment/assignees'
require_relative 'assignment/session'
require_relative 'task/continuation'
require_relative 'asset/project_assets'
require_relative 'diagnosis'
require_relative 'project_log'
require_relative 'step/start_next_step'
require_relative 'step/send_directive'

module AgenticRuntime
  class Hooks
    def initialize(runtime)
      @runtime = runtime.dup.freeze
      @root = Dir.pwd.freeze
      @workspace = Task::Workspace.new(root: @root)
      @assignees = Assignment::Assignees.new(root: @root)
      @continuation = Task::Continuation.new
      @assets = Asset::ProjectAssets.new(root: @root)
      @project_log = ProjectLog.new(root: @root, runtime: @runtime)
      freeze
    end

    def run(input:, stdout: $stdout)
      session = Assignment::Session.from_hook_input(runtime: @runtime, input: input)
      return respond(stdout) unless session

      assignment = @assignees.find_by(session: session)
      unless assignment
        @project_log.append(Diagnosis.warn('このセッションが担当するタスクがありません', session: session))
        return respond(stdout)
      end

      task = @workspace.find(assignment.task_id)

      decision = @continuation.decide(progress: task.progress)
      if decision == :done
        task.close
        @workspace.save(task)
        return respond(stdout, "タスク #{task.id} をクローズした。クローズしたことをユーザーへ伝えてターンを終了する。")
      end

      Step::StartNextStep.new(workspace: @workspace, assets: @assets, task: task).start if decision == :next

      respond(stdout, Step::SendDirective.new(root: @root, task: task).send(session: session))
    rescue JSON::ParserError
      @project_log.append(Diagnosis.warn('入力を JSON として読めません'))
      respond(stdout)
    rescue StandardError => e
      reason = "タスクを進められません: #{e.message}"
      @project_log.append(Diagnosis.error(reason, session: session))
      respond(stdout, reason)
    end

    private

    def respond(stdout, body = nil)
      response = if body
                   @runtime == 'cursor' ? { followup_message: body } : { decision: 'block', reason: body }
                 else
                   @runtime == 'codex' ? { continue: true } : {}
                 end
      stdout.puts(JSON.generate(response))
      0
    end
  end
end
