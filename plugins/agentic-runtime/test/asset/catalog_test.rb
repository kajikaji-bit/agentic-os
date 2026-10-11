# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'

require_relative '../../lib/agentic_runtime/asset/catalog'

class TestCatalog < Minitest::Test
  def test_find_a_workflow_by_name
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

      File.write(File.join(workflows, 'release-review.yaml'), <<~YAML)
        name: another-workflow
        description: 別の仕事をする
        steps:
          - name: 01-other
            description: 別の仕事を確認する
      YAML
      catalog = AgenticRuntime::Asset::Catalog.new(root: project)

      selected = catalog.find('release-review')

      assert_equal 'release-review', selected.name
      assert_equal ['01-inspect', '02-summarize'], selected.steps.map(&:name)
      assert_equal ['公開する変更点を確認する', '確認した結果をまとめる'], selected.steps.map(&:description)
    end
  end
end
