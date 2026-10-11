# frozen_string_literal: true

module AgenticRuntime
  class Event
    NAMES = %w[
      workspace.created task.created workflow.created session.attached step.started directive.sent
      report.approved completion.rejected step.completed step.cancelled task.closed
    ].freeze

    attr_reader :name, :attributes

    def self.from(record)
      raise ArgumentError, 'ログの行は対応表で指定してください' unless record.is_a?(Hash)

      new(name: record['event'], attributes: record.except('at', 'event'))
    end

    def initialize(name:, attributes:)
      raise ArgumentError, "イベント名が不正です: #{name}" unless NAMES.include?(name)
      raise ArgumentError, 'イベント別項目は対応表で指定してください' unless attributes.is_a?(Hash)
      raise ArgumentError, 'イベント別項目のキーは String で指定してください' unless attributes.keys.all?(String)

      @name = name.dup.freeze
      @attributes = attributes.dup.freeze
      freeze
    end
  end
end
