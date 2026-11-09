# frozen_string_literal: true

# What releases and pull requests depend on: the release version, one
# number written in flake.nix (the Nix package), spin.toml (the spin
# package) and lib/shipinel/version.rb (`shipinel --version`), and the
# GitHub workflows and issue forms. `rake version` prints the version for
# the "20 · Release" workflow, and `rake release_notes` its notes; `rake
# bump[x.y.z]` sets a new one in all three files;
# `rake check_version` fails when they differ; `rake yaml_checks` lints the
# YAML (.yamllint) and `rake shell_checks` the shell scripts.

require_relative "support/release_notes"
require_relative "support/version_bump"

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

# Example match: `VERSION = "0.1.0"` in lib/shipinel/version.rb.
RUBY_VERSION_LINE = /^\s*VERSION = "(?<version>\d+\.\d+\.\d+)"$/

# What `shipinel --version` prints.
def ruby_version
  File.read("lib/shipinel/version.rb")[RUBY_VERSION_LINE, :version]
end

desc "Print the release version"
task :version do
  puts flake_version
end

# Writes `file` back with what the block makes of its text.
def rewrite(file)
  File.write(file, yield(File.read(file)))
end

desc "Set the release version in flake.nix, spin.toml and lib/shipinel/version.rb: rake bump[0.3.0]"
task :bump, [:version] do |_task, args|
  version = args[:version].to_s
  VersionBump.check(version)
  rewrite("flake.nix") { |text| VersionBump.flake(text, version) }
  rewrite("spin.toml") { |text| VersionBump.spin(text, version) }
  rewrite("lib/shipinel/version.rb") { |text| VersionBump.ruby(text, version) }
  Rake::Task[:check_version].invoke
end

# The git output of `command` (no shell: the arguments are passed as they are).
def git(*command)
  IO.popen(["git", *command], &:read)
end

# The newest version tag reachable from `ending`, other than `tag`.
def previous_tag(tag, ending)
  git("tag", "--merged", ending, "--sort=-v:refname", "v*").split("\n").reject { |name| name == tag }.first
end

desc "Print the release notes for TAG (default v<version>): install lines, changes since the last tag"
task :release_notes, [:tag] do |_task, args|
  tag = args.fetch(:tag, "v#{flake_version}")
  ending = git("tag", "--list", tag).strip.empty? ? "HEAD" : tag
  previous = previous_tag(tag, ending)
  log = git("log", "--format=%s%x09%h", previous ? "#{previous}..#{ending}" : ending)
  commits = log.split("\n").map { |line| line.split("\t", 2) }
  puts ReleaseNotes.markdown(ENV.fetch("GITHUB_REPOSITORY", "fabiosammy/shipinel"), tag, previous, commits)
end

desc "Fail unless flake.nix, spin.toml and lib/shipinel/version.rb have the same version"
task :check_version do
  versions = { "flake.nix" => flake_version, "spin.toml" => spin_version,
               "lib/shipinel/version.rb" => ruby_version }
  unless versions.values.uniq.size == 1 && versions.values.first
    said = versions.map { |file, version| "#{file} says #{version.inspect}" }
    abort "versions differ: #{said.join(', ')}: bump all three"
  end
  puts "version #{versions.values.first}"
end

# actionlint knows the workflow syntax, the expressions and the action
# inputs, and runs shellcheck on every `run:` script. The files are named:
# it only finds them by itself in a Git checkout, and `nix flake check`
# builds from a copy without .git.
desc "Lint the shell scripts (the Linux bundle's build, the window test) with shellcheck"
task :shell_checks do
  sh "shellcheck", *Dir["packaging/**/*.sh", "test/**/*.sh"]
end

desc "Check the desktop entry (packaging/shipinel.desktop) with desktop-file-validate"
task :desktop_checks do
  sh "desktop-file-validate", "packaging/shipinel.desktop"
end

desc "Lint the YAML with yamllint (.yamllint) and the workflows with actionlint"
task :yaml_checks do
  sh "yamllint", "--strict", "."
  sh "actionlint", *Dir[".github/workflows/*.yml"]
end
