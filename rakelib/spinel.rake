# frozen_string_literal: true

# Spinel: widen-free compile, a clean `spin build`, snapshot tests, and
# `spinel diff` parity with CRuby.

require "shellwords"
require_relative "sources"
require_relative "support/checked_command"

SPINEL_CHECK_DIR = "build/spinel-check"
# Command lines `spinel diff` runs bin/shipinel.rb with (no window is opened).
CLI_DIFF_ARGS = [["--font-size", "big"], []].freeze

desc "Run every Spinel gate"
task spinel_checks: %i[spinel_widen spin_build spin_test spinel_diff]

desc "Compile every program with --rbs sig --warn-widen; any warning fails"
task :spinel_widen do
  mkdir_p SPINEL_CHECK_DIR
  spin_flags = Shellwords.split(CheckedCommand.run("spin", "flags"))
  Sources::SPINEL_PROGRAMS.each do |program|
    output = "#{SPINEL_CHECK_DIR}/#{File.basename(program, '.rb')}"
    CheckedCommand.run("spinel", *spin_flags, "--rbs", "sig", "--warn-widen", program, "-o", output)
  end
end

desc "spin build with no warnings"
task :spin_build do
  CheckedCommand.run("spin", "build")
end

desc "spin test: snapshot tests compiled by Spinel"
task :spin_test do
  CheckedCommand.run("spin", "test")
end

# `spinel diff` needs spinel-diff installed beside the compiler binary, which
# `make install` misses; flake.nix and docs/spinel-notes.md say how to fix it.
desc "spinel diff: CRuby and Spinel must print the same"
task :spinel_diff do
  runs = FileList["test/*.rb"].to_a.zip
  runs += CLI_DIFF_ARGS.map { |args| ["bin/shipinel.rb", "--", *args] }
  runs.each do |run|
    output = CheckedCommand.run("spinel", "diff", *run)
    abort "spinel diff: #{run.join(' ')} is not the same" unless output.start_with?("spinel diff: same")
  end
end
