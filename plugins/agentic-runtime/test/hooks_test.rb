# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'json'
require 'stringio'
require 'tmpdir'

require_relative '../lib/agentic_runtime/hooks'
require_relative '../lib/agentic_runtime/asset/catalog'
require_relative '../lib/agentic_runtime/task/workspace'
require_relative '../lib/agentic_runtime/assignment/assignees'
require_relative '../lib/agentic_runtime/assignment/session'
require_relative '../lib/agentic_runtime/asset/project_assets'
require_relative '../lib/agentic_runtime/task/create_task'
require_relative '../lib/agentic_runtime/assignment/attach_session'

class TestHooks < Minitest::Test
  def test_start_the_first_step_of_the_assigned_task
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'briefing.yaml'), <<~YAML)
        name: release-review
        description: 公開前に変更内容を確認する
        steps:
          - name: 01-inspect
            description: 公開する変更点を確認する
          - name: 02-summarize
            description: 確認した結果をまとめる
      YAML

      catalog = AgenticRuntime::Asset::Catalog.new(root: project)
      workspace = AgenticRuntime::Task::Workspace.new(root: project)
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      assignee = AgenticRuntime::Assignment::Session.from(runtime: 'codex', id: 'review-session')
      create_task = AgenticRuntime::Task::CreateTask.new(
        root: project, workspace: workspace, catalog: catalog, assets: assets,
        assignees: AgenticRuntime::Assignment::Assignees.new(root: project)
      )
      task = create_task.create(name: 'example', workflow_name: 'release-review', session: assignee)
      input = JSON.generate(hook_event_name: 'Stop', session_id: 'review-session')
      output = StringIO.new

      Dir.chdir(project) do
        hooks = AgenticRuntime::Hooks.new('codex')
        hooks.run(input: input, stdout: output)
      end

      response = JSON.parse(output.string)
      assert_equal 'block', response.fetch('decision')
      assert_includes response.fetch('reason'), '公開する変更点を確認する'
      assert_equal '01-inspect',
                   AgenticRuntime::Task::Workspace.new(root: project).find(task.id).progress.current_step_name
    end
  end

  def test_receive_the_next_instruction_after_completing_a_step
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'briefing.yaml'), <<~YAML)
        name: release-review
        steps:
          - name: 01-inspect
            description: 公開する変更点を確認する
          - name: 02-summarize
            description: 確認した結果をまとめる
      YAML

      catalog = AgenticRuntime::Asset::Catalog.new(root: project)
      workspace = AgenticRuntime::Task::Workspace.new(root: project)
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      assignee = AgenticRuntime::Assignment::Session.from(runtime: 'codex', id: 'review-session')
      create_task = AgenticRuntime::Task::CreateTask.new(
        root: project, workspace: workspace, catalog: catalog, assets: assets,
        assignees: AgenticRuntime::Assignment::Assignees.new(root: project)
      )
      task = create_task.create(name: 'example', workflow_name: 'release-review', session: assignee)
      task.plan.advance
      task.plan.current_step.complete
      workspace.save(task)
      FileUtils.rm(File.join(workflows, 'briefing.yaml'))
      input = JSON.generate(hook_event_name: 'Stop', session_id: 'review-session')
      output = StringIO.new

      Dir.chdir(project) do
        hooks = AgenticRuntime::Hooks.new('codex')
        hooks.run(input: input, stdout: output)
      end

      response = JSON.parse(output.string)
      assert_equal 'block', response.fetch('decision')
      assert_includes response.fetch('reason'), '確認した結果をまとめる'
      assert_includes response.fetch('reason'), "agentic-runtime step complete #{task.id} 02-summarize"
      saved = AgenticRuntime::Task::Workspace.new(root: project).find(task.id)
      assert_equal '02-summarize', saved.progress.current_step_name
    end
  end

  def test_do_not_repeat_the_instruction_while_the_step_is_in_progress
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'briefing.yaml'), <<~YAML)
        name: release-review
        steps:
          - name: 01-inspect
            description: 公開する変更点を確認する
          - name: 02-summarize
            description: 確認した結果をまとめる
      YAML

      catalog = AgenticRuntime::Asset::Catalog.new(root: project)
      workspace = AgenticRuntime::Task::Workspace.new(root: project)
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      assignee = AgenticRuntime::Assignment::Session.from(runtime: 'codex', id: 'review-session')
      create_task = AgenticRuntime::Task::CreateTask.new(
        root: project, workspace: workspace, catalog: catalog, assets: assets,
        assignees: AgenticRuntime::Assignment::Assignees.new(root: project)
      )
      task = create_task.create(name: 'example', workflow_name: 'release-review', session: assignee)
      input = JSON.generate(hook_event_name: 'Stop', session_id: 'review-session')
      first_output = StringIO.new
      repeated_output = StringIO.new
      Dir.chdir(project) do
        AgenticRuntime::Hooks.new('codex').run(input: input, stdout: first_output)
      end
      assert_includes JSON.parse(first_output.string).fetch('reason'), '公開する変更点を確認する'

      Dir.chdir(project) do
        AgenticRuntime::Hooks.new('codex').run(input: input, stdout: repeated_output)
      end

      assert_equal({ 'continue' => true }, JSON.parse(repeated_output.string))
      saved = AgenticRuntime::Task::Workspace.new(root: project).find(task.id)
      assert_equal '01-inspect', saved.progress.current_step_name
    end
  end

  def test_close_the_task_after_all_steps_are_completed
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'briefing.yaml'), <<~YAML)
        name: release-review
        steps:
          - name: 01-inspect
            description: 公開する変更点を確認する
      YAML

      catalog = AgenticRuntime::Asset::Catalog.new(root: project)
      workspace = AgenticRuntime::Task::Workspace.new(root: project)
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      assignee = AgenticRuntime::Assignment::Session.from(runtime: 'codex', id: 'review-session')
      create_task = AgenticRuntime::Task::CreateTask.new(
        root: project, workspace: workspace, catalog: catalog, assets: assets,
        assignees: AgenticRuntime::Assignment::Assignees.new(root: project)
      )
      task = create_task.create(name: 'example', workflow_name: 'release-review', session: assignee)
      task.plan.advance
      task.plan.current_step.complete
      workspace.save(task)
      input = JSON.generate(hook_event_name: 'Stop', session_id: 'review-session')
      output = StringIO.new

      Dir.chdir(project) do
        AgenticRuntime::Hooks.new('codex').run(input: input, stdout: output)
      end

      response = JSON.parse(output.string)
      assert_equal 'block', response['decision']
      assert_includes response.fetch('reason'), "タスク #{task.id} をクローズした"
      saved = AgenticRuntime::Task::Workspace.new(root: project).find(task.id)
      assert_equal 'closed', saved.progress.task_status
    end
  end

  def test_do_not_repeat_notifications_after_closing_the_task
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'briefing.yaml'), <<~YAML)
        name: release-review
        steps:
          - name: 01-inspect
            description: 公開する変更点を確認する
      YAML

      catalog = AgenticRuntime::Asset::Catalog.new(root: project)
      workspace = AgenticRuntime::Task::Workspace.new(root: project)
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      assignee = AgenticRuntime::Assignment::Session.from(runtime: 'codex', id: 'review-session')
      create_task = AgenticRuntime::Task::CreateTask.new(
        root: project, workspace: workspace, catalog: catalog, assets: assets,
        assignees: AgenticRuntime::Assignment::Assignees.new(root: project)
      )
      task = create_task.create(name: 'example', workflow_name: 'release-review', session: assignee)
      task.plan.advance
      task.plan.current_step.complete
      workspace.save(task)
      input = JSON.generate(hook_event_name: 'Stop', session_id: 'review-session')
      first_output = StringIO.new
      repeated_output = StringIO.new
      Dir.chdir(project) do
        AgenticRuntime::Hooks.new('codex').run(input: input, stdout: first_output)
      end
      first_response = JSON.parse(first_output.string)
      assert_equal 'block', first_response['decision']
      assert_includes first_response.fetch('reason'), "タスク #{task.id} をクローズした"

      Dir.chdir(project) do
        AgenticRuntime::Hooks.new('codex').run(input: input, stdout: repeated_output)
      end

      assert_equal({ 'continue' => true }, JSON.parse(repeated_output.string))
      saved = AgenticRuntime::Task::Workspace.new(root: project).find(task.id)
      assert_equal 'closed', saved.progress.task_status
    end
  end

  def test_receive_the_instruction_in_progress_once_after_a_handoff
    Dir.mktmpdir('agentic-runtime-component-') do |project|
      workflows = File.join(project, '.agents/workflows')
      FileUtils.mkdir_p(workflows)
      File.write(File.join(workflows, 'briefing.yaml'), <<~YAML)
        name: release-review
        steps:
          - name: 01-inspect
            description: 公開する変更点を確認する
          - name: 02-summarize
            description: 確認した結果をまとめる
      YAML

      catalog = AgenticRuntime::Asset::Catalog.new(root: project)
      workspace = AgenticRuntime::Task::Workspace.new(root: project)
      assets = AgenticRuntime::Asset::ProjectAssets.new(root: project)
      assignees = AgenticRuntime::Assignment::Assignees.new(root: project)
      assignee = AgenticRuntime::Assignment::Session.from(runtime: 'codex', id: 'review-session')
      create_task = AgenticRuntime::Task::CreateTask.new(
        root: project, workspace: workspace, catalog: catalog, assets: assets, assignees: assignees
      )
      task = create_task.create(name: 'example', workflow_name: 'release-review', session: assignee)
      Dir.chdir(project) do
        AgenticRuntime::Hooks.new('codex').run(
          input: JSON.generate(hook_event_name: 'Stop', session_id: 'review-session'), stdout: StringIO.new
        )
      end
      successor = AgenticRuntime::Assignment::Session.from(runtime: 'claude', id: 'successor-session')
      AgenticRuntime::Assignment::AttachSession.new(workspace: workspace, assignees: assignees)
                                               .attach(task_id: task.id, session: successor)
      input = JSON.generate(hook_event_name: 'Stop', session_id: 'successor-session')
      first_output = StringIO.new
      repeated_output = StringIO.new

      Dir.chdir(project) do
        AgenticRuntime::Hooks.new('claude').run(input: input, stdout: first_output)
      end

      response = JSON.parse(first_output.string)
      assert_equal 'block', response.fetch('decision')
      assert_includes response.fetch('reason'), '公開する変更点を確認する'
      assert_equal '01-inspect',
                   AgenticRuntime::Task::Workspace.new(root: project).find(task.id).progress.current_step_name
      Dir.chdir(project) do
        AgenticRuntime::Hooks.new('claude').run(input: input, stdout: repeated_output)
      end
      assert_equal({}, JSON.parse(repeated_output.string))
    end
  end
end
