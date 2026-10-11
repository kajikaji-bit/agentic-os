# frozen_string_literal: true

require 'date'

module AgenticRuntime
  module Task
    class TaskId
      def self.generate(name)
        new("#{Time.now.getlocal('+09:00').strftime('%Y%m%d')}-#{name}")
      end

      def self.parse(value)
        new(value)
      end

      def to_s
        @value
      end

      def ==(other)
        other.is_a?(TaskId) && to_s == other.to_s
      end

      private

      def initialize(value)
        match = /\A(?<year>\d{4})(?<month>\d{2})(?<day>\d{2})-[a-z0-9]+(?:-[a-z0-9]+)*\z/.match(value)
        raise ArgumentError, "タスク ID の形ではありません: #{value}" unless match
        unless Date.valid_date?(match[:year].to_i, match[:month].to_i, match[:day].to_i)
          raise ArgumentError, "タスク ID の日付が不正です: #{value}"
        end

        @value = value.dup.freeze
        freeze
      end

      private_class_method :new
    end
  end
end
