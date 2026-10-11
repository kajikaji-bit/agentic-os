# frozen_string_literal: true

require_relative '../event'
require_relative 'check_completion'

module AgenticRuntime
  module Step
    class Step
      class CompletionRejected < StandardError
        attr_reader :task_id, :step_name, :unmet

        def initialize(task_id:, step_name:, unmet:)
          @task_id = task_id
          @step_name = step_name.dup.freeze
          @unmet = unmet
          super('完了条件を満たしていません')
        end
      end

      attr_reader :name, :status

      def self.start(task_id:, definition:, directory:, assets:)
        new(task_id: task_id, definition: definition, directory: directory, assets: assets, status: 'started',
            events: [Event.new(name: 'step.started', attributes: { 'step' => definition.name })])
      end

      def self.restore(task_id:, definition:, directory:, assets:, status:)
        new(task_id: task_id, definition: definition, directory: directory, assets: assets, status: status,
            events: [])
      end

      def complete(approval_evidence: nil)
        raise ArgumentError, '進行中のステップではありません' unless @status == 'started'

        if approval_evidence
          @events << Event.new(name: 'report.approved',
                               attributes: { 'step' => @name, 'evidence' => approval_evidence })
        end
        verdict = @check_completion.compare(
          required_artifacts: @definition.artifacts, artifacts: @directory.artifacts,
          required_checks: @assets.checks(definition: @definition), checklists: @directory.checklists,
          approval_required: @definition.approval_required?, approval_evidence: approval_evidence
        )
        unless verdict.accepted?
          @events << Event.new(name: 'completion.rejected', attributes: { 'step' => @name, 'unmet' => verdict.unmet })
          raise CompletionRejected.new(task_id: @task_id, step_name: @name, unmet: verdict.unmet)
        end

        @events << Event.new(name: 'step.completed', attributes: { 'step' => @name })
        @status = 'completed'
        nil
      end

      def cancel
        raise ArgumentError, '進行中のステップではありません' unless @status == 'started'

        @events << Event.new(name: 'step.cancelled', attributes: { 'step' => @name })
        @status = 'cancelled'
        nil
      end

      def release_events
        @events.dup.freeze
      end

      def clear_events
        @events.clear
        nil
      end

      private

      def initialize(task_id:, definition:, directory:, assets:, status:, events:)
        raise ArgumentError, 'ステップの状態が不正です' unless %w[started completed cancelled].include?(status)

        @task_id = task_id
        @definition = definition
        @directory = directory
        @assets = assets
        @check_completion = CheckCompletion.new
        @name = definition.name
        @status = status.dup.freeze
        @events = events.dup
      end

      private_class_method :new
    end
  end
end
