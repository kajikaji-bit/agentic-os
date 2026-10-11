# frozen_string_literal: true

module AgenticRuntime
  class Diagnosis
    attr_reader :level, :reason, :session

    def self.warn(reason, session: nil)
      new(level: 'warn', reason: reason, session: session)
    end

    def self.error(reason, session: nil)
      new(level: 'error', reason: reason, session: session)
    end

    private

    def initialize(level:, reason:, session:)
      raise ArgumentError, '理由が必要です' unless reason.is_a?(String) && /\S/.match?(reason)

      @level = level.dup.freeze
      @reason = reason.dup.freeze
      @session = session
      freeze
    end

    private_class_method :new
  end
end
