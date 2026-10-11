# frozen_string_literal: true

require_relative '../task/workspace'
require_relative '../workspace_path'

module AgenticRuntime
  module Project
    class Doctor
      class Result
        attr_reader :inconsistencies

        def ok?
          @inconsistencies.empty?
        end

        def initialize(inconsistencies:)
          @inconsistencies = inconsistencies.map { |inconsistency| inconsistency.dup.freeze }.freeze
          freeze
        end
      end

      def initialize(root:)
        @root = File.expand_path(root).freeze
        @workspace = Task::Workspace.new(root: @root)
        freeze
      end

      def check(task_id: nil)
        ids = @workspace.paths.map(&:task_id)
        raise ArgumentError, "タスクがありません: #{task_id}" if task_id && !ids.include?(task_id)

        targets = task_id ? [task_id] : ids
        restored = {}
        inconsistencies = targets.flat_map do |id|
          task = @workspace.find(id)
          restored[id] = task
          copy_inconsistencies(task_id: id, progress: task.progress)
        rescue ArgumentError, KeyError, SystemCallError => e
          ["#{id}: ログからタスクを復元できません (#{e.message})"]
        end

        Result.new(inconsistencies: inconsistencies + assignment_inconsistencies(restored))
      end

      private

      def copy_inconsistencies(task_id:, progress:)
        copies = { 'state' => progress.task_status, 'current_step' => progress.current_step_name.to_s }
        copies.filter_map do |file, logged|
          path = File.join(WorkspacePath.for(root: @root, task_id: task_id).value, file)
          next "#{task_id}: #{file} の写しがありません" unless File.exist?(path)

          copy = File.read(path).chomp
          next if copy == logged

          "#{task_id}: #{file} の写しがログと食い違います (写し: #{copy}、ログ: #{logged})"
        end
      end

      def assignment_inconsistencies(tasks)
        assigned = tasks.filter_map do |task_id, task|
          next if task.progress.task_status == 'closed'

          path = File.join(WorkspacePath.for(root: @root, task_id: task_id).value, 'session')
          next unless File.exist?(path)

          [File.read(path).strip, task_id]
        end

        assigned.group_by(&:first).filter_map do |session, pairs|
          next if pairs.size < 2

          "#{session}: クローズしていないタスクを二つ以上担当しています (#{pairs.map(&:last).join('、')})"
        end
      end
    end
  end
end
