# frozen_string_literal: true

# Development tasks only: runs under CRuby and is never compiled by Spinel.
# `rake check` is the gate every phase must pass; the tasks live in rakelib/.

task default: :check

desc "Run every quality gate: Ruby, types, native code, Spinel"
task check: %i[
  check_version yaml_checks shell_checks desktop_checks
  ruby_checks type_checks native_checks spinel_checks
]
