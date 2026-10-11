#!/usr/bin/env ruby
# frozen_string_literal: true

test_files = if ARGV.empty?
               Dir[File.expand_path('**/*_test.rb', __dir__)]
             else
               ARGV.map { |path| File.expand_path(path) }
             end
ARGV.clear
test_files.sort.each { |path| require path }
