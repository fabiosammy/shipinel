# frozen_string_literal: true

# What releases and pull requests depend on: the release version, one
# number written in flake.nix (the Nix package) and spin.toml (the spin
# package), and the GitHub workflows and issue forms. `rake version` prints
# the version for the "20 · Release" workflow; `rake check_version` fails
# when the two differ; `rake yaml_checks` lints the YAML (.yamllint).

# Example match: `version = "0.1.0";` in flake.nix's package, or
# `version = "0.1.0"` in spin.toml.
VERSION_LINE = /^\s*version = "(?<version>\d+\.\d+\.\d+)";?\s*$/

# The package's version in flake.nix comes after `pname = "shipinel";`
# (the file also pins Spinel's own version).
def flake_version
  text = File.read("flake.nix")
  text[text.index('pname = "shipinel";')..][VERSION_LINE, :version]
end

def spin_version
  File.read("spin.toml")[VERSION_LINE, :version]
end

desc "Print the release version"
task :version do
  puts flake_version
end

desc "Fail unless flake.nix and spin.toml have the same version"
task :check_version do
  flake = flake_version
  spin = spin_version
  abort "flake.nix says #{flake.inspect}, spin.toml says #{spin.inspect}: bump both" unless flake && flake == spin
  puts "version #{flake}"
end

# actionlint knows the workflow syntax, the expressions and the action
# inputs, and runs shellcheck on every `run:` script.
desc "Lint the YAML with yamllint (.yamllint) and the workflows with actionlint"
task :yaml_checks do
  sh "yamllint", "--strict", "."
  sh "actionlint"
end
