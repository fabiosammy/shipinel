# frozen_string_literal: true

# Sets a new release version in the three files that hold it: flake.nix
# (the shipinel package, not the Spinel it pins), spin.toml and
# lib/shipinel/version.rb. Works on the files' text, so `rake bump` only
# reads and writes, and the tests need no files.

# See the file comment.
module VersionBump
  # Example match: "0.3.0"; no "v", no pre-release suffix.
  SEMVER = /\A\d+\.\d+\.\d+\z/
  PACKAGE = 'pname = "shipinel";'

  # Raises unless `version` is a plain x.y.z.
  def self.check(version)
    raise ArgumentError, "#{version.inspect} is not a version like 0.3.0" unless SEMVER.match?(version)
  end

  # Only the version after `pname = "shipinel";` changes.
  def self.flake(text, version)
    start = text.index(PACKAGE) or raise ArgumentError, "flake.nix has no #{PACKAGE}"
    package = text[start..].sub(/^(\s*version = )"\d+\.\d+\.\d+";$/) { "#{Regexp.last_match(1)}\"#{version}\";" }
    text[0...start] + package
  end

  def self.spin(text, version)
    text.sub(/^version = "\d+\.\d+\.\d+"$/, %(version = "#{version}"))
  end

  def self.ruby(text, version)
    text.sub(/^(\s*VERSION = )"\d+\.\d+\.\d+"$/) { "#{Regexp.last_match(1)}\"#{version}\"" }
  end
end
