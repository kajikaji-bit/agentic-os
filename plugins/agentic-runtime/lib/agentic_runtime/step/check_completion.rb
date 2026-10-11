# frozen_string_literal: true

require_relative 'completion_verdict'

module AgenticRuntime
  module Step
    class CheckCompletion
      def initialize
        freeze
      end

      def compare(required_artifacts:, artifacts:, required_checks:, checklists:,
                  approval_required:, approval_evidence:)
        CompletionVerdict.new(unmet: missing_artifacts(required_artifacts, artifacts) +
                                     unfinished_checks(required_checks, checklists) +
                                     missing_approval(approval_required, approval_evidence))
      end

      private

      def missing_artifacts(required_artifacts, artifacts)
        required_artifacts.filter_map do |declaration|
          next if artifacts.any? { |file| File.fnmatch?(declaration, file, File::FNM_PATHNAME | File::FNM_EXTGLOB) }

          { condition: "artifact:#{declaration}", correction: "成果物 #{declaration} を作成する" }
        end
      end

      def unfinished_checks(required_checks, checklists)
        required_checks.filter_map do |name|
          next if checklists[name]&.checked?

          { condition: "check:#{name}", correction: "Checklist #{name} の未チェックの項目を解いてチェックを付ける" }
        end
      end

      def missing_approval(approval_required, approval_evidence)
        return [] unless approval_required
        return [] if /\S/.match?(approval_evidence.to_s)

        [{ condition: 'approval', correction: '承認者本人の発言を指定する' }]
      end
    end
  end
end
