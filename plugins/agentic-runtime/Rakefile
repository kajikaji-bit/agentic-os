# frozen_string_literal: true

require 'rake/testtask'

RUBOCOP_PATHS = %w[bin/agentic-runtime lib test hooks Rakefile Gemfile].select { |path| File.exist?(path) }.freeze

desc 'Run the complete test suite'
Rake::TestTask.new(:test) do |test|
  test.libs << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.warning = false
end

desc 'Run tests and enforce minimum coverage'
task :coverage do
  require 'simplecov'
  SimpleCov.start do
    command_name 'Minitest'
    enable_coverage :branch
    cover(*%w[bin/agentic-runtime hooks/**/*.rb lib/**/*.rb])
    minimum_coverage line: 90, branch: 80
  end
  ARGV.clear
  load File.expand_path('test/run.rb', __dir__)
end

desc 'Inspect Ruby files with RuboCop'
task :rubocop do
  sh(*(%w[bundle exec rubocop --cache false] + RUBOCOP_PATHS))
end

desc 'Run every development gate'
task default: %i[test rubocop]
