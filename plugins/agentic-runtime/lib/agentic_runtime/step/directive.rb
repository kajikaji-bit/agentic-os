# frozen_string_literal: true

require 'erb'

module AgenticRuntime
  module Step
    # Directive は View Model として、取得済みの仕事を指示文に組み立てて保持し、取得や配送を追加で行わない。
    class Directive
      attr_reader :body

      def initialize(task_id:, step_definition:, workspace_path:, rules:, role:, skills:, reading_list:, checklists:)
        template = ERB.new(<<~'BODY', trim_mode: '-')
          以下の指示に従ってステップを実行してください。

          ## やること
          <%= step_definition.description %>

          <%- if role -%>
          ## あなたの役割
          <%= role.description %>
          <%= role.body %>

          <%- end -%>
          <%- if rules.any? -%>
          ## ルール
          <%= rules.map(&:body).join("\n\n") %>

          <%- end -%>
          ## ワークスペース
          <%= workspace_path %>
          進行中のステップは <%= step_definition.name %> にある。

          <%- if skills.any? -%>
          ## 使用するスキル
          <%- skills.each do |path| -%>
          - <%= path %>
          <%- end -%>

          <%- end -%>
          <%- if reading_list.any? -%>
          ## 読むもの
          <%- reading_list.each do |path| -%>
          - <%= path %>
          <%- end -%>

          <%- end -%>
          <%- if checklists.any? -%>
          ## チェックリスト
          <%- checklists.each do |checklist| -%>
          - <%= checklist.path %>
          <%- end -%>

          <%- end -%>
          <%- if step_definition.approval_required? -%>
          ## 承認を依頼する
          このステップの完了には承認が必要。ユーザーへ承認を求め、ターンを終了する。

          ## ステップを完了させる
          agentic-runtime step complete <%= task_id %> <%= step_definition.name %> --approval-evidence '<承認者本人の発言>'
          <%- else -%>
          ## ステップを完了させる
          agentic-runtime step complete <%= task_id %> <%= step_definition.name %>
          <%- end -%>
        BODY

        @body = template.result_with_hash(
          task_id: task_id,
          step_definition: step_definition,
          workspace_path: workspace_path,
          rules: rules,
          role: role,
          skills: skills,
          reading_list: reading_list,
          checklists: checklists
        )
        @body.freeze
        freeze
      end
    end
  end
end
