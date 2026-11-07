# frozen_string_literal: true

# Spinel: widen-free compile, a clean `spin build`, snapshot tests, and
# `spinel diff` parity with CRuby.

require "shellwords"
require_relative "sources"
require_relative "support/checked_command"

SPINEL_CHECK_DIR = "build/spinel-check"

desc "Run every Spinel gate"
task spinel_checks: %i[spinel_widen spin_build spin_test spinel_diff]

# spin feeds every .rbs below the project root to Spinel, so a stray one
# (generated, copied, left over) would silently change what is compiled.
desc "Fail if any .rbs file exists outside sig/"
task :rbs_only_in_sig do
  stray = FileList["**/*.rbs"].exclude("sig/**/*.rbs").to_a
  abort "rbs files outside sig/ would be read by spin: #{stray.join(', ')}" if stray.any?
end

desc "Compile every program with --rbs sig --warn-widen; any warning fails"
task spinel_widen: :rbs_only_in_sig do
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
# bin/shipinel.rb is not diffed: it requires the FFI module, which CRuby
# cannot load. The test programs cover every non-UI path it uses.
desc "spinel diff: CRuby and Spinel must print the same"
task :spinel_diff do
  FileList["test/*.rb"].each do |program|
    output = CheckedCommand.run("spinel", "diff", program)
    abort "spinel diff: #{program} is not the same" unless output.start_with?("spinel diff: same")
  end
end
