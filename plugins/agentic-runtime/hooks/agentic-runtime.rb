#!/usr/bin/env ruby
# frozen_string_literal: true

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require_relative '../lib/agentic_runtime/hooks'

exit AgenticRuntime::Hooks.new(ARGV.fetch(0)).run(input: $stdin.read, stdout: $stdout)
