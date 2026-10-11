# frozen_string_literal: true

require_relative '../helper'
require_relative '../../lib/agentic_runtime/asset/project_assets'
require_relative '../../lib/agentic_runtime/asset/workflow'

class TestProjectRules < Minitest::Test
  include Helper

  def test_wiki_rule_supplies_body_and_reading_list_to_instruction
    Dir.mktmpdir('agentic-runtime-') do |project|
      write(project, '.agents/workflows/publish.yaml', <<~YAML)
        name: publish
        steps:
          - name: 01-update
            description: 公開対象を更新する
            rules:
              - publish-agentic-os-scope
      YAML
      write(project, 'wiki/agentic-os/publish-agentic-os-scope.rule.md', <<~MARKDOWN)
        ---
        read:
          - wiki/agentic-os/scope.yaml
        ---

        - 公開先への反映は Outbox に任せる。
      MARKDOWN
      write(project, 'wiki/agentic-os/scope.yaml', "- wiki/agentic-os/mission.template.md\n")
      env = session_env('codex', 'wiki-rule-session')
      response = run_cli(project, 'task create example --workflow publish', env: env)
      assert_equal 0, response.code
      instruction = run_stop(project, 'codex', session_id: 'wiki-rule-session')
      assert_instruction instruction, 'codex', '- 公開先への反映は Outbox に任せる。'
      assert_instruction instruction, 'codex', 'wiki/agentic-os/scope.yaml'
      rule = assets(project).rules(definition: definition).first
      assert_equal 'publish-agentic-os-scope', rule.name
    end
  end

  def test_legacy_rule_remains_available
    Dir.mktmpdir('agentic-runtime-') do |project|
      write(project, '.agents/rules/publish-agentic-os-scope.md', "---\n{}\n---\n旧ルール\n")
      write(project, 'wiki/other/unrelated.rule.md', "# 通常の Wiki ページ\n")
      rule = assets(project).rules(definition: definition).first
      assert_equal 'publish-agentic-os-scope', rule.name
      assert_equal '旧ルール', rule.body
    end
  end

  def test_duplicate_names_are_rejected_across_legacy_and_wiki_locations
    Dir.mktmpdir('agentic-runtime-') do |project|
      write(project, '.agents/rules/publish-agentic-os-scope.md', "---\n{}\n---\n旧ルール\n")
      write(project, 'wiki/os/publish-agentic-os-scope.rule.md', "---\n{}\n---\n新ルール\n")
      error = assert_raises(ArgumentError) { assets(project).rules(definition: definition) }
      assert_includes error.message, 'ルールが重複しています'
    end
  end

  def test_duplicate_names_are_rejected_across_wiki_domains
    Dir.mktmpdir('agentic-runtime-') do |project|
      %w[os other].each do |domain|
        write(project, "wiki/#{domain}/publish-agentic-os-scope.rule.md", "---\n{}\n---\nルール\n")
      end
      error = assert_raises(ArgumentError) { assets(project).rules(definition: definition) }
      assert_includes error.message, 'ルールが重複しています'
    end
  end

  def test_wiki_rule_requires_frontmatter
    Dir.mktmpdir('agentic-runtime-') do |project|
      write(project, 'wiki/os/publish-agentic-os-scope.rule.md', "# フロントマターなし\n")
      error = assert_raises(ArgumentError) { assets(project).rules(definition: definition) }
      assert_includes error.message, 'frontmatter がありません'
    end
  end

  def test_wiki_rule_cannot_point_outside_project
    Dir.mktmpdir('agentic-runtime-') do |project|
      Dir.mktmpdir('external-rule-') do |external|
        source = write(external, 'external.rule.md', "---\n{}\n---\n外部ルール\n")
        FileUtils.mkdir_p(File.join(project, 'wiki/os'))
        File.symlink(source, File.join(project, 'wiki/os/publish-agentic-os-scope.rule.md'))
        error = assert_raises(ArgumentError) { assets(project).rules(definition: definition) }
        assert_includes error.message, 'ルールがプロジェクトの外を指しています'
      end
    end
  end

  private

  def assets(project)
    AgenticRuntime::Asset::ProjectAssets.new(root: project)
  end

  def definition
    AgenticRuntime::Step::StepDefinition.new(
      name: '01-update', description: '更新する', rules: ['publish-agentic-os-scope']
    )
  end

  def write(project, path, text)
    full_path = File.join(project, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, text)
    full_path
  end
end
